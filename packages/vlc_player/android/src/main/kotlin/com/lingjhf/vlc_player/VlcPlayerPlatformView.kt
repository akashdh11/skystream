package com.lingjhf.vlc_player

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.MediaPlayer.ScaleType
import org.videolan.libvlc.interfaces.IMedia
import org.videolan.libvlc.interfaces.IVLCVout
import org.videolan.libvlc.util.VLCVideoLayout

internal class VlcPlayerPlatformView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewIdentifier: Int,
    options: ArrayList<String>,
    fit: String,
    private val onDispose: (Long, VlcPlayerPlatformView) -> Unit,
) : PlatformView, MediaPlayer.EventListener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val videoLayout = VLCVideoLayout(context)
    private val libVLC = LibVLC(context, options)
    private val mediaPlayer = MediaPlayer(libVLC)
    private var videoScale = scaleTypeFor(fit)
    private val eventChannel = EventChannel(messenger, "vlc_player/events/$viewIdentifier")
    private val streamHandler = StreamHandler()
    private val viewId = viewIdentifier.toLong()
    private val attachStateListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) {
            scheduleAttachViews()
        }

        override fun onViewDetachedFromWindow(view: View) {
            releaseViews()
        }
    }
    private val layoutChangeListener = object : View.OnLayoutChangeListener {
        override fun onLayoutChange(
            view: View,
            left: Int,
            top: Int,
            right: Int,
            bottom: Int,
            oldLeft: Int,
            oldTop: Int,
            oldRight: Int,
            oldBottom: Int,
        ) {
            if (
                left != oldLeft ||
                top != oldTop ||
                right != oldRight ||
                bottom != oldBottom
            ) {
                scheduleAttachViews()
            }
        }
    }
    private val voutCallback = object : IVLCVout.Callback {
        override fun onSurfacesCreated(vlcVout: IVLCVout) {
            if (disposed) {
                return
            }
            viewsAttached = true
            mediaPlayer.setVideoScale(videoScale)
            sendSnapshot()
        }

        override fun onSurfacesDestroyed(vlcVout: IVLCVout) {
            viewsAttached = false
            if (disposed || detachingViews) {
                return
            }
            mainHandler.post {
                if (!disposed) {
                    releaseViews()
                    scheduleAttachViews()
                }
            }
        }
    }

    private var state = STATE_IDLE
    private var volume = 100
    private var playbackSpeed = 1.0f
    private var bufferingProgress: Double? = null
    private var errorCode: String? = null
    private var errorDescription: String? = null
    private var lastSentEvent: Map<String, Any?>? = null
    private var viewsAttached = false
    private var detachingViews = false
    private var attachViewsPosted = false
    private var disposed = false

    init {
        videoLayout.setBackgroundColor(Color.BLACK)
        videoLayout.addOnAttachStateChangeListener(attachStateListener)
        videoLayout.addOnLayoutChangeListener(layoutChangeListener)
        mediaPlayer.setEventListener(this)
        mediaPlayer.vlcVout.addCallback(voutCallback)
        scheduleAttachViews()
        eventChannel.setStreamHandler(streamHandler)
    }

    override fun getView(): View = videoLayout

    fun setSource(
        uri: String,
        httpHeaders: Map<String, String>,
        mediaOptions: List<String>,
        startPosition: Long,
        autoPlay: Boolean,
        result: MethodChannel.Result,
    ) {
        if (!ensureActive(result)) {
            return
        }

        try {
            val media = Media(libVLC, Uri.parse(uri))
            httpHeaders.forEach { (name, value) ->
                if (isValidHeader(name, value)) {
                    media.addOption(":http-header=$name: $value")
                }
            }
            mediaOptions.forEach { option ->
                media.addOption(option)
            }
            if (startPosition > 0L) {
                media.addOption(":start-time=${startPosition / 1000.0}")
            }
            mediaPlayer.media = media
            media.release()
            errorCode = null
            errorDescription = null
            lastSentEvent = null
            updateState(STATE_OPENING)
            if (autoPlay) {
                mediaPlayer.play()
            }
            result.success(null)
        } catch (error: RuntimeException) {
            errorCode = ERROR_SET_SOURCE_FAILED
            errorDescription = error.message
            updateState(STATE_ERROR)
            result.error(ERROR_SET_SOURCE_FAILED, error.message, null)
        }
    }

    private fun isValidHeader(name: String, value: String): Boolean {
        return name.isNotBlank() &&
            !name.contains('\r') &&
            !name.contains('\n') &&
            !value.contains('\r') &&
            !value.contains('\n')
    }

    fun play(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        mediaPlayer.play()
        result.success(null)
    }

    fun pause(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        mediaPlayer.pause()
        result.success(null)
    }

    fun stop(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        mediaPlayer.stop()
        updateState(STATE_STOPPED)
        result.success(null)
    }

    fun seekTo(milliseconds: Long, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        mediaPlayer.time = milliseconds.coerceAtLeast(0L)
        sendSnapshot()
        result.success(null)
    }

    fun setVolume(volume: Int, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        this.volume = volume.coerceIn(0, 200)
        mediaPlayer.volume = this.volume
        sendSnapshot()
        result.success(null)
    }

    fun setPlaybackSpeed(speed: Float, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        if (!speed.isFinite() || speed <= 0.0f) {
            result.error("invalid_args", "A finite positive playback speed is required.", null)
            return
        }
        playbackSpeed = speed
        mediaPlayer.rate = playbackSpeed
        sendSnapshot()
        result.success(null)
    }

    fun setAudioDelay(microseconds: Long, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        if (!mediaPlayer.setAudioDelay(microseconds)) {
            result.error("vlc_error", "VLC failed to set audio delay.", null)
            return
        }
        sendSnapshot()
        result.success(null)
    }

    fun setSubtitleDelay(microseconds: Long, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        if (!mediaPlayer.setSpuDelay(microseconds)) {
            result.error("vlc_error", "VLC failed to set subtitle delay.", null)
            return
        }
        sendSnapshot()
        result.success(null)
    }

    fun takeSnapshot(width: Int, height: Int, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        val activity = activityFrom(context)
        if (activity == null) {
            result.error("snapshot_failed", "Unable to locate the Android activity window.", null)
            return
        }
        if (videoLayout.width <= 0 || videoLayout.height <= 0) {
            result.error("snapshot_failed", "The video view has no rendered size.", null)
            return
        }

        val location = IntArray(2)
        videoLayout.getLocationInWindow(location)
        val sourceRect = Rect(
            location[0],
            location[1],
            location[0] + videoLayout.width,
            location[1] + videoLayout.height,
        )
        val snapshotWidth = if (width > 0) width else videoLayout.width
        val snapshotHeight = if (height > 0) height else videoLayout.height
        val bitmap = Bitmap.createBitmap(snapshotWidth, snapshotHeight, Bitmap.Config.ARGB_8888)

        PixelCopy.request(activity.window, sourceRect, bitmap, { copyResult ->
            if (copyResult != PixelCopy.SUCCESS) {
                bitmap.recycle()
                result.error("snapshot_failed", "Android PixelCopy failed with code $copyResult.", null)
                return@request
            }
            val output = ByteArrayOutputStream()
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                bitmap.recycle()
                result.error("snapshot_failed", "Android failed to encode the snapshot PNG.", null)
                return@request
            }
            bitmap.recycle()
            result.success(output.toByteArray())
        }, mainHandler)
    }

    fun getAudioTracks(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        result.success(trackDescriptions(mediaPlayer.audioTracks))
    }

    fun setAudioTrack(id: Int, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        if (!mediaPlayer.setAudioTrack(id)) {
            result.error("track_not_found", "Audio track $id was not found.", null)
            return
        }
        result.success(null)
    }

    fun getSubtitleTracks(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        result.success(trackDescriptions(mediaPlayer.spuTracks))
    }

    fun setSubtitleTrack(id: Int, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        if (!mediaPlayer.setSpuTrack(id)) {
            result.error("track_not_found", "Subtitle track $id was not found.", null)
            return
        }
        result.success(null)
    }

    fun disableSubtitle(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        mediaPlayer.setSpuTrack(-1)
        result.success(null)
    }

    fun addSubtitle(uri: String, result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }
        if (!mediaPlayer.addSlave(IMedia.Slave.Type.Subtitle, Uri.parse(uri), true)) {
            result.error("add_subtitle_failed", "Failed to add subtitle: $uri", null)
            return
        }
        result.success(null)
    }

    fun getMediaInfo(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }

        val media = mediaPlayer.media
        if (media == null) {
            result.success(emptyMediaInfo())
            return
        }
        result.success(mediaInfo(media, mediaPlayer.length))
    }

    fun getMediaStats(result: MethodChannel.Result) {
        if (!ensureActive(result)) {
            return
        }

        result.success(mediaStats(mediaPlayer.media?.getStats()))
    }

    private fun mediaInfo(media: IMedia, playerLength: Long): Map<String, Any?> {
        val info = HashMap<String, Any?>()
        info["title"] = media.getMeta(IMedia.Meta.Title)
        info["artist"] = media.getMeta(IMedia.Meta.Artist)
        info["album"] = media.getMeta(IMedia.Meta.Album)
        info["duration"] = maxOf(media.duration, playerLength, 0L)

        val videoTracks = ArrayList<Map<String, Any?>>()
        val audioTracks = ArrayList<Map<String, Any?>>()
        val subtitleTracks = ArrayList<Map<String, Any?>>()
        for (index in 0 until media.trackCount) {
            val track = media.getTrack(index) ?: continue
            val trackInfo = mediaTrackInfo(track)
            when (track.type) {
                IMedia.Track.Type.Video -> videoTracks.add(trackInfo)
                IMedia.Track.Type.Audio -> audioTracks.add(trackInfo)
                IMedia.Track.Type.Text -> subtitleTracks.add(trackInfo)
            }
        }
        info["videoTracks"] = videoTracks
        info["audioTracks"] = audioTracks
        info["subtitleTracks"] = subtitleTracks
        return info
    }

    override fun onFlutterViewAttached(flutterView: View) {
        if (!disposed) {
            scheduleAttachViews()
        }
    }

    override fun onFlutterViewDetached() {
        detachViewsIfNeeded()
    }

    override fun dispose() {
        if (disposed) {
            return
        }
        disposed = true
        eventChannel.setStreamHandler(null)
        mediaPlayer.setEventListener(null)
        videoLayout.removeOnAttachStateChangeListener(attachStateListener)
        videoLayout.removeOnLayoutChangeListener(layoutChangeListener)
        mediaPlayer.vlcVout.removeCallback(voutCallback)
        mediaPlayer.stop()
        releaseViews()
        mediaPlayer.release()
        libVLC.release()
        onDispose(viewId, this)
    }

    override fun onEvent(event: MediaPlayer.Event) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            handlePlayerEvent(event)
        } else {
            mainHandler.post { handlePlayerEvent(event) }
        }
    }

    private fun handlePlayerEvent(event: MediaPlayer.Event) {
        if (disposed) {
            return
        }

        when (event.type) {
            MediaPlayer.Event.Opening -> {
                bufferingProgress = null
                updateState(STATE_OPENING)
            }
            MediaPlayer.Event.Buffering -> {
                bufferingProgress =
                    event.getBuffering().coerceIn(0.0f, 100.0f).toDouble() / 100.0
                updateState(STATE_BUFFERING)
            }
            MediaPlayer.Event.Playing -> {
                bufferingProgress = null
                updateState(STATE_PLAYING)
            }
            MediaPlayer.Event.Paused -> {
                bufferingProgress = null
                updateState(STATE_PAUSED)
            }
            MediaPlayer.Event.Stopped -> {
                bufferingProgress = null
                updateState(STATE_STOPPED)
            }
            MediaPlayer.Event.EndReached -> {
                bufferingProgress = null
                updateState(STATE_ENDED)
            }
            MediaPlayer.Event.EncounteredError -> {
                bufferingProgress = null
                errorCode = ERROR_PLAYBACK
                errorDescription = "VLC encountered an error while playing the media."
                updateState(STATE_ERROR)
            }
            MediaPlayer.Event.TimeChanged,
            MediaPlayer.Event.PositionChanged,
            MediaPlayer.Event.LengthChanged,
            MediaPlayer.Event.SeekableChanged,
            MediaPlayer.Event.Vout,
            MediaPlayer.Event.ESAdded,
            MediaPlayer.Event.ESDeleted,
            MediaPlayer.Event.ESSelected,
            -> sendSnapshot()
        }
    }

    private fun updateState(state: String) {
        this.state = state
        sendSnapshot()
    }

    /// Changes how video is scaled without recreating the player.
    ///
    /// setVideoScale is already a runtime call on MediaPlayer; only the Dart
    /// side forced a rebuild, by folding `fit` into the platform-view key.
    fun setFit(fit: String, result: MethodChannel.Result) {
        if (disposed) {
            result.error("disposed", "This player has been disposed.", null)
            return
        }
        videoScale = scaleTypeFor(fit)
        mediaPlayer.setVideoScale(videoScale)
        result.success(null)
    }

    private fun attachViewsIfNeeded() {
        if (disposed || viewsAttached || !videoLayout.isAttachedToWindow) {
            return
        }
        releaseViews()
        mediaPlayer.attachViews(videoLayout, null, false, true)
        mediaPlayer.setVideoScale(videoScale)
        viewsAttached = true
    }

    private fun scheduleAttachViews() {
        if (disposed || attachViewsPosted) {
            return
        }
        attachViewsPosted = true
        mainHandler.post {
            attachViewsPosted = false
            attachViewsIfNeeded()
        }
    }

    private fun detachViewsIfNeeded() {
        releaseViews()
    }

    private fun releaseViews() {
        detachingViews = true
        try {
            mediaPlayer.detachViews()
            viewsAttached = false
        } finally {
            detachingViews = false
        }
    }

    private fun ensureActive(result: MethodChannel.Result): Boolean {
        if (!disposed) {
            return true
        }
        result.error("disposed", "The vlc_player has been disposed.", null)
        return false
    }

    private fun trackDescriptions(
        tracks: Array<MediaPlayer.TrackDescription>?,
    ): List<Map<String, Any?>> {
        return tracks.orEmpty().map { track ->
            mapOf(
                "id" to track.id,
                "name" to track.name,
                "language" to null,
            )
        }
    }

    private fun emptyMediaInfo(): Map<String, Any?> {
        return mapOf(
            "title" to null,
            "artist" to null,
            "album" to null,
            "duration" to 0L,
            "videoTracks" to emptyList<Map<String, Any?>>(),
            "audioTracks" to emptyList<Map<String, Any?>>(),
            "subtitleTracks" to emptyList<Map<String, Any?>>(),
        )
    }

    private fun mediaStats(stats: IMedia.Stats?): Map<String, Any> {
        return mapOf(
            "available" to (stats != null),
            "readBytes" to (stats?.readBytes ?: 0),
            "inputBitrate" to (stats?.inputBitrate?.toDouble() ?: 0.0),
            "demuxReadBytes" to (stats?.demuxReadBytes ?: 0),
            "demuxBitrate" to (stats?.demuxBitrate?.toDouble() ?: 0.0),
            "demuxCorrupted" to (stats?.demuxCorrupted ?: 0),
            "demuxDiscontinuity" to (stats?.demuxDiscontinuity ?: 0),
            "decodedVideo" to (stats?.decodedVideo ?: 0),
            "decodedAudio" to (stats?.decodedAudio ?: 0),
            "displayedPictures" to (stats?.displayedPictures ?: 0),
            "lostPictures" to (stats?.lostPictures ?: 0),
            "playedAudioBuffers" to (stats?.playedAbuffers ?: 0),
            "lostAudioBuffers" to (stats?.lostAbuffers ?: 0),
            "sentPackets" to (stats?.sentPackets ?: 0),
            "sentBytes" to (stats?.sentBytes ?: 0),
            "sendBitrate" to (stats?.sendBitrate?.toDouble() ?: 0.0),
        )
    }

    private fun mediaTrackInfo(track: IMedia.Track): Map<String, Any?> {
        val info = HashMap<String, Any?>()
        info["type"] = trackTypeName(track.type)
        info["codec"] = track.codec
        info["language"] = track.language
        info["bitrate"] = track.bitrate.takeIf { it > 0 }
        if (track is IMedia.VideoTrack) {
            info["width"] = track.width.takeIf { it > 0 }
            info["height"] = track.height.takeIf { it > 0 }
        }
        if (track is IMedia.AudioTrack) {
            info["channels"] = track.channels.takeIf { it > 0 }
            info["sampleRate"] = track.rate.takeIf { it > 0 }
        }
        return info
    }

    private fun trackTypeName(type: Int): String {
        return when (type) {
            IMedia.Track.Type.Audio -> "audio"
            IMedia.Track.Type.Video -> "video"
            IMedia.Track.Type.Text -> "subtitle"
            else -> "unknown"
        }
    }

    private fun sendSnapshot(force: Boolean = false) {
        if (disposed) {
            return
        }

        val duration = mediaPlayer.length.coerceAtLeast(0L)
        val isSeekable = mediaPlayer.isSeekable
        val event = HashMap<String, Any?>()
        event["state"] = state
        event["position"] = mediaPlayer.time.coerceAtLeast(0L)
        event["duration"] = duration
        event["volume"] = volume
        event["playbackSpeed"] = playbackSpeed.toDouble()
        event["audioDelay"] = mediaPlayer.audioDelay
        event["subtitleDelay"] = mediaPlayer.spuDelay
        event["isReady"] = isReadyState(state)
        event["isSeekable"] = isSeekable
        event["isLive"] = isLiveState(state) && duration == 0L && !isSeekable
        videoSize()?.let {
            event["videoSize"] = it
        }
        bufferingProgress?.let {
            event["bufferingProgress"] = it
        }
        errorDescription?.let {
            event["errorCode"] = errorCode ?: ERROR_PLAYBACK
            event["errorDescription"] = it
        }
        if (!force && event == lastSentEvent) {
            return
        }
        lastSentEvent = HashMap(event)
        streamHandler.send(event)
    }

    private fun videoSize(): Map<String, Int>? {
        val track = mediaPlayer.currentVideoTrack ?: return null
        val width = track.width
        val height = track.height
        if (width <= 0 || height <= 0) {
            return null
        }
        return mapOf("width" to width, "height" to height)
    }

    private inner class StreamHandler : EventChannel.StreamHandler {
        private var events: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            this.events = events
            sendSnapshot(force = true)
        }

        override fun onCancel(arguments: Any?) {
            events = null
        }

        fun send(event: Map<String, Any?>) {
            if (Looper.myLooper() == Looper.getMainLooper()) {
                sendOnMainThread(event)
            } else {
                mainHandler.post { sendOnMainThread(event) }
            }
        }

        private fun sendOnMainThread(event: Map<String, Any?>) {
            if (!disposed) {
                events?.success(event)
            }
        }
    }

    private companion object {
        const val STATE_IDLE = "idle"
        const val STATE_OPENING = "opening"
        const val STATE_BUFFERING = "buffering"
        const val STATE_PLAYING = "playing"
        const val STATE_PAUSED = "paused"
        const val STATE_STOPPED = "stopped"
        const val STATE_ENDED = "ended"
        const val STATE_ERROR = "error"
        const val ERROR_PLAYBACK = "playback_error"
        const val ERROR_SET_SOURCE_FAILED = "set_source_failed"

        fun scaleTypeFor(fit: String): ScaleType {
            return when (fit) {
                "cover" -> ScaleType.SURFACE_FIT_SCREEN
                "fill" -> ScaleType.SURFACE_FILL
                "none" -> ScaleType.SURFACE_ORIGINAL
                else -> ScaleType.SURFACE_BEST_FIT
            }
        }

        fun activityFrom(context: Context): Activity? {
            var current = context
            while (current is ContextWrapper) {
                if (current is Activity) {
                    return current
                }
                current = current.baseContext
            }
            return null
        }

        fun isReadyState(state: String): Boolean {
            return state == STATE_PLAYING ||
                state == STATE_PAUSED ||
                state == STATE_STOPPED ||
                state == STATE_ENDED
        }

        fun isLiveState(state: String): Boolean {
            // STATE_BUFFERING is deliberately excluded. isLive is derived from
            // `duration == 0 && !isSeekable`, and both are trivially true while
            // VLC is still opening the stream — including buffering made every
            // VOD report isLive for the first frames.
            return state == STATE_PLAYING || state == STATE_PAUSED
        }
    }
}
