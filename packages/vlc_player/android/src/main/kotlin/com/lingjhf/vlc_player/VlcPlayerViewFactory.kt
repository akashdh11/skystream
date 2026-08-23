package com.lingjhf.vlc_player

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class VlcPlayerViewFactory(
    private val messenger: BinaryMessenger,
    private val onCreate: (Long, VlcPlayerPlatformView) -> Unit,
    private val onDispose: (Long, VlcPlayerPlatformView) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(viewContext: Context, viewId: Int, args: Any?): PlatformView {
        val view = VlcPlayerPlatformView(
            viewContext,
            messenger,
            viewId,
            readOptions(args),
            readFit(args),
            onDispose,
        )
        onCreate(viewId.toLong(), view)
        return view
    }

    private fun readOptions(args: Any?): ArrayList<String> {
        val options = ArrayList<String>()
        val rawOptions = (args as? Map<*, *>)?.get("options") as? List<*> ?: return options

        rawOptions.forEach { option ->
            if (option != null) {
                options.add(option.toString())
            }
        }
        return options
    }

    private fun readFit(args: Any?): String {
        return ((args as? Map<*, *>)?.get("fit") as? String) ?: "contain"
    }
}
