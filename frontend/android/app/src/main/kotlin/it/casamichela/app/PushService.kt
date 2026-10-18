package it.casamichela.app

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.MethodChannel

// Firebase calls in on its own threads; Flutter's channel wants the main one.
object PushBridge {
    var channel: MethodChannel? = null

    private val main = Handler(Looper.getMainLooper())

    fun tell(method: String, argument: Any?) {
        main.post { channel?.invokeMethod(method, argument) }
    }
}

// Firebase posts a push under its tag with id 0.
object PushTray {
    private const val TAG_PREFIX = "notification-"

    // While the app is open Firebase leaves the showing to it: posted as Firebase would.
    fun show(context: Context, id: Int, title: String?, body: String?, messageId: String?) {
        val open = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("google.message_id", messageId.orEmpty())
            .putExtra("id", id.toString())
        val tap = PendingIntent.getActivity(
            context,
            id,
            open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, context.getString(R.string.notification_channel_id))
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_ALL)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(context.getColor(R.color.notification_accent))
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(tap)
            .build()

        context.getSystemService(NotificationManager::class.java)
            .notify("$TAG_PREFIX$id", 0, notification)
    }

    fun dismiss(context: Context, id: Int) {
        context.getSystemService(NotificationManager::class.java).cancel("$TAG_PREFIX$id", 0)
    }

    // Takes off what the app's list says is read or gone; one posted after it was asked for may be new.
    fun tidy(context: Context, unread: Set<Int>, listed: Set<Int>, listedAt: Long) {
        val manager = context.getSystemService(NotificationManager::class.java)

        for (shown in manager.activeNotifications) {
            val tag = shown.tag ?: continue

            if (!tag.startsWith(TAG_PREFIX)) {
                continue
            }

            val id = tag.removePrefix(TAG_PREFIX).toIntOrNull() ?: continue

            if (id !in unread && (id in listed || shown.postTime < listedAt)) {
                manager.cancel(tag, shown.id)
            }
        }
    }

    // Signed out: every notification of the account leaves the tray.
    fun clear(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)

        for (shown in manager.activeNotifications) {
            val tag = shown.tag ?: continue

            if (tag.startsWith(TAG_PREFIX)) {
                manager.cancel(tag, shown.id)
            }
        }
    }
}

// The system shows a push itself while the app is closed; this hears the rest.
class PushService : FirebaseMessagingService() {
    // Notifications only while the app is open; dismissals always.
    override fun onMessageReceived(message: RemoteMessage) {
        val id = message.data["id"]?.toIntOrNull() ?: return

        if (message.data["type"] == "dismiss") {
            PushTray.dismiss(this, id)
            PushBridge.tell("dismissed", id)
            return
        }

        message.notification?.let {
            PushTray.show(this, id, it.title, it.body, message.messageId)
        }

        PushBridge.tell("arrived", id)
    }

    // The app hands the new token to the server the next time it hears of it.
    override fun onNewToken(token: String) {
        PushBridge.tell("renewed", null)
    }
}
