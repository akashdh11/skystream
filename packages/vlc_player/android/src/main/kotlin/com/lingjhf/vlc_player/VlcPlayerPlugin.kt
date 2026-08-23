package com.lingjhf.vlc_player

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Android implementation for the vlc_player plugin. */
class VlcPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private val players = HashMap<Long, VlcPlayerPlatformView>()
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        channel = MethodChannel(messenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            VlcPlayerViewFactory(
                messenger,
                onCreate = { viewId, player ->
                    players.remove(viewId)?.dispose()
                    players[viewId] = player
                },
                onDispose = { viewId, player ->
                    if (players[viewId] === player) {
                        players.remove(viewId)
                    }
                },
            ),
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val rawViewId = call.argument<Number>("viewId")
        if (rawViewId == null) {
            result.error("invalid_args", "A valid viewId is required.", null)
            return
        }

        val viewId = rawViewId.toLong()
        if (call.method == "dispose") {
            disposePlayer(viewId)
            result.success(null)
            return
        }

        val player = players[viewId]
        if (player == null) {
            result.error("player_not_found", "No vlc_player player exists for viewId $viewId.", null)
            return
        }

        when (call.method) {
            "setSource" -> {
                val uri = call.argument<String>("uri")
                val autoPlay = call.argument<Boolean>("autoPlay") == true
                val httpHeaders = call.argument<Map<String, String>>("httpHeaders").orEmpty()
                val mediaOptions = call.argument<List<String>>("mediaOptions").orEmpty()
                val startPosition = call.argument<Number>("startPosition")?.toLong() ?: 0L
                if (uri.isNullOrEmpty()) {
                    result.error("invalid_args", "A non-empty uri is required.", null)
                    return
                }
                if (startPosition < 0L) {
                    result.error("invalid_args", "A non-negative startPosition is required.", null)
                    return
                }
                player.setSource(uri, httpHeaders, mediaOptions, startPosition, autoPlay, result)
            }
            "play" -> player.play(result)
            "pause" -> player.pause(result)
            "stop" -> player.stop(result)
            "seekTo" -> {
                val position = call.argument<Number>("position")?.toLong()
                if (position == null || position < 0L) {
                    result.error("invalid_args", "A non-negative position is required.", null)
                    return
                }
                player.seekTo(position, result)
            }
            "setVolume" -> {
                val volume = call.argument<Number>("volume")?.toInt()
                if (volume == null) {
                    result.error("invalid_args", "A volume value is required.", null)
                    return
                }
                player.setVolume(volume, result)
            }
            "setPlaybackSpeed" -> {
                val speed = call.argument<Number>("speed")?.toFloat()
                if (speed == null || !speed.isFinite() || speed <= 0.0f) {
                    result.error("invalid_args", "A finite positive playback speed is required.", null)
                    return
                }
                player.setPlaybackSpeed(speed, result)
            }
            "setAudioDelay" -> {
                val delay = call.argument<Number>("delay")?.toLong()
                if (delay == null) {
                    result.error("invalid_args", "An audio delay value is required.", null)
                    return
                }
                player.setAudioDelay(delay, result)
            }
            "setSubtitleDelay" -> {
                val delay = call.argument<Number>("delay")?.toLong()
                if (delay == null) {
                    result.error("invalid_args", "A subtitle delay value is required.", null)
                    return
                }
                player.setSubtitleDelay(delay, result)
            }
            "takeSnapshot" -> {
                val rawWidth = call.argument<Number>("width")?.toInt()
                val rawHeight = call.argument<Number>("height")?.toInt()
                if ((rawWidth != null && rawWidth <= 0) || (rawHeight != null && rawHeight <= 0)) {
                    result.error("invalid_args", "Snapshot dimensions must be positive.", null)
                    return
                }
                val width = rawWidth ?: 0
                val height = rawHeight ?: 0
                player.takeSnapshot(width, height, result)
            }
            "getAudioTracks" -> player.getAudioTracks(result)
            "setAudioTrack" -> {
                val id = call.argument<Number>("id")?.toInt()
                if (id == null || id < 0) {
                    result.error("invalid_args", "A non-negative audio track id is required.", null)
                    return
                }
                player.setAudioTrack(id, result)
            }
            "getSubtitleTracks" -> player.getSubtitleTracks(result)
            "setSubtitleTrack" -> {
                val id = call.argument<Number>("id")?.toInt()
                if (id == null || id < 0) {
                    result.error("invalid_args", "A non-negative subtitle track id is required.", null)
                    return
                }
                player.setSubtitleTrack(id, result)
            }
            "disableSubtitle" -> player.disableSubtitle(result)
            "addSubtitle" -> {
                val uri = call.argument<String>("uri")
                if (uri.isNullOrEmpty()) {
                    result.error("invalid_args", "A non-empty subtitle uri is required.", null)
                    return
                }
                player.addSubtitle(uri, result)
            }
            "getMediaInfo" -> player.getMediaInfo(result)
            "getMediaStats" -> player.getMediaStats(result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        players.values.toList().forEach { it.dispose() }
        players.clear()
    }

    private fun disposePlayer(viewId: Long) {
        players.remove(viewId)?.dispose()
    }

    private companion object {
        const val CHANNEL_NAME = "vlc_player"
        const val VIEW_TYPE = "plugins.lingjhf.com/vlc_player/view"
    }
}
