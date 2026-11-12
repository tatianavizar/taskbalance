package app.cinquante.mobile

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import app.cinquante.mobile.bridge.ConfirmComponent
import app.cinquante.mobile.bridge.DatePickerComponent
import app.cinquante.mobile.bridge.OverflowMenuComponent
import app.cinquante.mobile.bridge.PushNotificationsComponent
import app.cinquante.mobile.bridge.SettingsComponent
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration

class CinquanteApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        configureHotwire()
        createNotificationChannel()
    }

    private fun configureHotwire() {
        // The server recognises the shell by "Hotwire Native Android" in the user
        // agent (turbo-rails' hotwire_native_app?); Hotwire adds it after this prefix.
        Hotwire.config.applicationUserAgentPrefix = "50-50 Android;"
        Hotwire.config.jsonConverter = KotlinXJsonConverter()
        Hotwire.config.debugLoggingEnabled = BuildConfig.DEBUG
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        // Bundled rules first (app/src/main/assets/json/configuration.json), then
        // the server's copy (ConfigurationsController), cached for the next launch.
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/configuration.json",
                remoteFileUrl = "${BuildConfig.BASE_URL}/configurations/android_v1.json"
            )
        )

        // Names must match the web controllers in app/javascript/controllers/bridge/.
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("push-notifications", ::PushNotificationsComponent),
            BridgeComponentFactory("settings", ::SettingsComponent),
            BridgeComponentFactory("date-picker", ::DatePickerComponent),
            BridgeComponentFactory("overflow-menu", ::OverflowMenuComponent),
            BridgeComponentFactory("confirm", ::ConfirmComponent)
        )
        // Network errors and offline (G1): HotwireWebFragment shows its own error
        // view with a retry button; nothing custom here.
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            getString(R.string.notification_channel_id),
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
