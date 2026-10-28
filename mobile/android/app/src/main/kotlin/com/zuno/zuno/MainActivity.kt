package com.zuno.zuno

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Android's own share chooser (WhatsApp, Instagram, Facebook, …) and document viewer, for
        // lib/core/share/system_share_native.dart. A few lines here instead of a package for each.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "share" -> share(call, result)
                    "openFile" -> openFile(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun share(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")
        if (text.isNullOrBlank()) {
            result.error("empty", "Nothing to share.", null)
            return
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

    /**
     * Writes the bytes to the app's cache and opens them in whatever viewer the phone has.
     *
     * Every earlier document is cleared first: these are ID cards and resumes, and the cache should
     * hold only the one being looked at. The name comes from the server, but is still reduced to
     * plain characters so it can never step outside the folder.
     */
    private fun openFile(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
        val name = (call.argument<String>("fileName") ?: "document")
            .replace(Regex("[^A-Za-z0-9._ -]"), "_")
            .trimStart('.')
            .ifBlank { "document" }

        if (bytes == null || bytes.isEmpty()) {
            result.error("empty", "Nothing to open.", null)
            return
        }

        val folder = File(cacheDir, DOCUMENTS_FOLDER)
        folder.deleteRecursively()
        folder.mkdirs()

        val file = File(folder, name)
        file.writeBytes(bytes)

        val uri = FileProvider.getUriForFile(this, "$packageName.documents", file)
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(Intent.createChooser(view, name))
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("unavailable", e.message, null)
        }
    }

    private companion object {
        // Must match SystemShare._channel in system_share_native.dart.
        const val SHARE_CHANNEL = "com.zuno.zuno/share"

        // Must match the cache-path in res/xml/document_paths.xml.
        const val DOCUMENTS_FOLDER = "documents"
    }
}
