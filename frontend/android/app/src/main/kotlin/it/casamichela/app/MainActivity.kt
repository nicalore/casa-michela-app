package it.casamichela.app

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

private const val FILES_CHANNEL = "it.casamichela.app/files"
private const val SAVE_REQUEST = 4101

private const val NOTIFICATIONS_CHANNEL = "it.casamichela.app/notifications"
private const val NOTIFICATIONS_REQUEST = 4102
private const val NOTIFICATIONS_PREFERENCES = "notifications"
private const val NOTIFICATIONS_ASKED = "asked"

class MainActivity : FlutterActivity() {
    private class PendingSave(val bytes: ByteArray, val result: MethodChannel.Result)

    private var pendingSave: PendingSave? = null

    private var pendingPermission: MethodChannel.Result? = null

    // The notification tapped to open the app, until Flutter asks for it.
    private var openedNotification: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        openedNotification = notificationOf(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler(::onFilesCall)

        val notifications = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
        notifications.setMethodCallHandler(::onNotificationsCall)
        PushBridge.channel = notifications

        createNotificationChannel()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        PushBridge.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // A tap on a notification while the app was already open.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        notificationOf(intent)?.let { PushBridge.tell("opened", it) }
    }

    // Firebase hands the push's data to the activity it opens.
    private fun notificationOf(intent: Intent?): Int? {
        val extras = intent?.extras ?: return null

        if (!extras.containsKey("google.message_id")) {
            return null
        }

        return extras.getString("id")?.toIntOrNull()
    }

    // Before Android 8 there are no channels; the name shows in the system's settings.
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            getString(R.string.notification_channel_id),
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        )

        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun onNotificationsCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(notificationStatus())
            "request" -> requestNotifications(result)
            "openSettings" -> result.success(openNotificationSettings())
            "token" -> pushToken(result)
            "deleteToken" -> deletePushToken(result)
            "takeOpened" -> {
                result.success(openedNotification)
                openedNotification = null
            }
            "tidy" -> {
                PushTray.tidy(
                    this,
                    unread = call.argument<List<Number>>("unread").orEmpty().map { it.toInt() }.toSet(),
                    listed = call.argument<List<Number>>("listed").orEmpty().map { it.toInt() }.toSet(),
                    listedAt = call.argument<Number>("listedAt")?.toLong() ?: 0L,
                )
                result.success(null)
            }
            "clear" -> {
                PushTray.clear(this)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // Asking for it registers the app with Firebase the first time.
    private fun pushToken(result: MethodChannel.Result) {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                result.success(task.result)
            } else {
                result.error("no_token", task.exception?.message, null)
            }
        }
    }

    private fun deletePushToken(result: MethodChannel.Result) {
        FirebaseMessaging.getInstance().deleteToken().addOnCompleteListener { task ->
            result.success(task.isSuccessful)
        }
    }

    // "granted", "prompt" while the system can still ask, "denied" once only its settings can.
    private fun notificationStatus(): String {
        if (getSystemService(NotificationManager::class.java).areNotificationsEnabled()) {
            return "granted"
        }

        // Before Android 13 there is no question, and granted here means switched off in settings.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            return "denied"
        }

        // The rationale flag is false both before the first question and after a final no.
        val asked = getSharedPreferences(NOTIFICATIONS_PREFERENCES, MODE_PRIVATE)
            .getBoolean(NOTIFICATIONS_ASKED, false)

        return if (!asked || shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
            "prompt"
        } else {
            "denied"
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        val status = notificationStatus()

        if (status != "prompt" || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(status)
            return
        }

        if (pendingPermission != null) {
            result.error("busy", null, null)
            return
        }

        pendingPermission = result
        getSharedPreferences(NOTIFICATIONS_PREFERENCES, MODE_PRIVATE)
            .edit()
            .putBoolean(NOTIFICATIONS_ASKED, true)
            .apply()

        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATIONS_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != NOTIFICATIONS_REQUEST) {
            return
        }

        val result = pendingPermission ?: return
        pendingPermission = null

        result.success(notificationStatus())
    }

    // This app's notification page, or its whole settings page before Android 8.
    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
        }

        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
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
