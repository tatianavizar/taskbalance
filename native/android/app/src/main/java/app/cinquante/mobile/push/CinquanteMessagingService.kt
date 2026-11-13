package app.cinquante.mobile.push

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import app.cinquante.mobile.MainActivity
import app.cinquante.mobile.R
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * FCM (lot 8b). In the background the system shows the notification itself
 * and a tap opens MainActivity with the data keys as extras ("path").
 * In the foreground this service shows it, with the same "path".
 */
class CinquanteMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        // Stored only; the page sends it to the server on its next load
        // (bridge component « push-notifications », event "connect").
        PushPermission.storeToken(this, token)
    }

    @SuppressLint("MissingPermission") // checked above, SecurityException caught
    override fun onMessageReceived(message: RemoteMessage) {
        val notification = message.notification ?: return
        if (PushPermission.permission(this) != PushPermission.GRANTED) return

        val path = message.data[MainActivity.EXTRA_PATH]
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (path != null) putExtra(MainActivity.EXTRA_PATH, path)
        }
        val requestCode = (message.data["notification_id"] ?: message.messageId ?: "0").hashCode()
        val pendingIntent = PendingIntent.getActivity(
            this, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val built = NotificationCompat.Builder(this, getString(R.string.notification_channel_id))
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(notification.title)
            .setContentText(notification.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(notification.body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(requestCode, built)
        } catch (_: SecurityException) {
            // Permission withdrawn between the check and the post.
        }
    }
}
