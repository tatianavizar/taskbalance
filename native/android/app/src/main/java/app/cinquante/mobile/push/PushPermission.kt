package app.cinquante.mobile.push

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging

/**
 * The notification permission and the FCM token, as the
 * « push-notifications » bridge component reports them to the page:
 * { permission, token, platform: "android", previousToken }.
 */
object PushPermission {
    const val GRANTED = "granted"
    const val DENIED = "denied"
    const val NOT_DETERMINED = "not_determined"

    private const val PREFS = "push"
    private const val KEY_TOKEN = "token"
    private const val KEY_ASKED = "asked"

    /** Set by MainActivity: launches the system prompt (Android 13+). */
    var launcher: (() -> Unit)? = null

    private var pendingResult: ((Boolean) -> Unit)? = null

    data class State(val permission: String, val token: String?, val previousToken: String?)

    fun permission(context: Context): String {
        if (NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return GRANTED
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (granted) return GRANTED
        }
        return if (prefs(context).getBoolean(KEY_ASKED, false) || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            DENIED
        } else {
            NOT_DETERMINED
        }
    }

    /** Shows the system prompt when it can, then calls back with the granted state. */
    fun request(context: Context, callback: (Boolean) -> Unit) {
        val current = permission(context)
        val launch = launcher
        if (current == GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || launch == null) {
            callback(current == GRANTED)
            return
        }
        prefs(context).edit().putBoolean(KEY_ASKED, true).apply()
        pendingResult = callback
        launch()
    }

    fun onResult(granted: Boolean) {
        pendingResult?.invoke(granted)
        pendingResult = null
    }

    /**
     * The current state. Granted: the FCM token (fetched, then cached). Not
     * granted: the token the server may still hold, once, so the page can
     * unregister it.
     */
    fun state(context: Context, callback: (State) -> Unit) {
        val permission = permission(context)
        if (permission != GRANTED) {
            val previous = storedToken(context)
            if (previous != null) storeToken(context, null)
            callback(State(permission, null, previous))
            return
        }
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token ->
                storeToken(context, token)
                callback(State(GRANTED, token, null))
            }
            .addOnFailureListener {
                callback(State(GRANTED, storedToken(context), null))
            }
    }

    fun storeToken(context: Context, token: String?) {
        prefs(context).edit().putString(KEY_TOKEN, token).apply()
    }

    private fun storedToken(context: Context): String? = prefs(context).getString(KEY_TOKEN, null)

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
