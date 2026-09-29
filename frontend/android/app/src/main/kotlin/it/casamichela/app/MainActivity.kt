package it.casamichela.app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

private const val FILES_CHANNEL = "it.casamichela.app/files"
private const val SAVE_REQUEST = 4101

class MainActivity : FlutterActivity() {
    private class PendingSave(val bytes: ByteArray, val result: MethodChannel.Result)

    private var pendingSave: PendingSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler(::onFilesCall)
    }

    // The system's own save dialog, as iOS offers the Files app: the user
    // picks where the file goes, and no storage permission is needed.
    private fun onFilesCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveFile") {
            result.notImplemented()
            return
        }

        val bytes = call.argument<ByteArray>("bytes")
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType")

        if (bytes == null || fileName == null || mimeType == null) {
            result.error("bad_arguments", null, null)
            return
        }

        if (pendingSave != null) {
            result.error("busy", null, null)
            return
        }

        pendingSave = PendingSave(bytes, result)

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mimeType)
            .putExtra(Intent.EXTRA_TITLE, fileName)

        startActivityForResult(intent, SAVE_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != SAVE_REQUEST) {
            return
        }

        val save = pendingSave ?: return
        pendingSave = null

        val uri = data?.data

        if (resultCode != Activity.RESULT_OK || uri == null) {
            save.result.success(false)
            return
        }

        // The chosen place may be a cloud provider: written off the main thread.
        Thread {
            val error = try {
                contentResolver.openOutputStream(uri)?.use { it.write(save.bytes) }
                    ?: throw IOException("No stream for $uri")
                null
            } catch (e: Exception) {
                e
            }

            runOnUiThread {
                if (error == null) {
                    save.result.success(true)
                } else {
                    save.result.error("write_failed", error.message, null)
                }
            }
        }.start()
    }
}
