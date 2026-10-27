package com.zuno.zuno

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Android's own share chooser (WhatsApp, Instagram, Facebook, …), for
        // lib/core/share/system_share_native.dart. A few lines here instead of a share package.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "share") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val text = call.argument<String>("text")
                if (text.isNullOrBlank()) {
                    result.error("empty", "Nothing to share.", null)
                    return@setMethodCallHandler
                }

                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                    call.argument<String>("title")?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
                }

                try {
                    startActivity(Intent.createChooser(send, call.argument<String>("title")))
                    result.success(null)
                } catch (e: ActivityNotFoundException) {
                    result.error("unavailable", e.message, null)
                }
            }
    }

    private companion object {
        // Must match SystemShare._channel in system_share_native.dart.
        const val SHARE_CHANNEL = "com.zuno.zuno/share"
    }
}
