package app.cinquante.mobile

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import app.cinquante.mobile.push.PushPermission
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration

/**
 * Four tabs (Accueil, Tâches, Bilan, Foyer), one Hotwire navigator each, the
 * same as the web tab bar (hidden in the shells by the server).
 */
class MainActivity : HotwireActivity() {
    private lateinit var bottomNavigation: BottomNavigationView

    private data class Tab(val itemId: Int, val hostId: Int, val configuration: NavigatorConfiguration)

    private val tabs = listOf(
        tab(R.id.tab_home, R.id.navigator_home, "home", "/dashboard"),
        tab(R.id.tab_tasks, R.id.navigator_tasks, "tasks", "/chores"),
        tab(R.id.tab_report, R.id.navigator_report, "report", "/bilan"),
        tab(R.id.tab_household, R.id.navigator_household, "household", "/foyer")
    )

    // H1 (Android 13+): the system prompt, started by the push-notifications component.
    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            PushPermission.onResult(granted)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        PushPermission.launcher = { permissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS) }

        bottomNavigation = findViewById(R.id.bottom_navigation)
        bottomNavigation.setOnItemSelectedListener { item ->
            tabs.firstOrNull { it.itemId == item.itemId }?.let { select(it) }
            true
        }
        // A second tap on the current tab goes back to its first screen.
        bottomNavigation.setOnItemReselectedListener {
            delegate.currentNavigator?.clearAll()
        }
        showHost(tabs.first())

        if (savedInstanceState == null) handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        PushPermission.launcher = null
        super.onDestroy()
    }

    override fun navigatorConfigurations() = tabs.map { it.configuration }

    private fun tab(itemId: Int, hostId: Int, name: String, path: String) = Tab(
        itemId = itemId,
        hostId = hostId,
        configuration = NavigatorConfiguration(
            name = name,
            startLocation = "${BuildConfig.BASE_URL}$path",
            navigatorHostId = hostId
        )
    )

    private fun select(tab: Tab) {
        showHost(tab)
        delegate.setCurrentNavigator(tab.configuration)
    }

    private fun showHost(selected: Tab) {
        tabs.forEach { tab ->
            findViewById<View>(tab.hostId).visibility = if (tab == selected) View.VISIBLE else View.GONE
        }
    }

    /**
     * A notification tap (extra "path", e.g. /notifications/123, which marks it
     * read and redirects to its screen) or an App Link (https://cinquante.app/...).
     * Both open in the Accueil tab.
     */
    private fun handleIntent(intent: Intent?) {
        val url = urlFrom(intent) ?: return
        // Consume it, so a configuration change does not route it again.
        intent?.removeExtra(EXTRA_PATH)
        intent?.data = null

        bottomNavigation.selectedItemId = R.id.tab_home
        select(tabs.first())
        // The navigator host is ready once the first layout pass is done.
        window.decorView.post { delegate.currentNavigator?.route(url) }
    }

    private fun urlFrom(intent: Intent?): String? {
        intent ?: return null
        intent.getStringExtra(EXTRA_PATH)?.takeIf { it.startsWith("/") }?.let {
            return "${BuildConfig.BASE_URL}$it"
        }
        val data: Uri = intent.data ?: return null
        val base = Uri.parse(BuildConfig.BASE_URL)
        return if (intent.action == Intent.ACTION_VIEW && data.host == base.host) data.toString() else null
    }

    companion object {
        const val EXTRA_PATH = "path"
    }
}
