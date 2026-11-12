package app.cinquante.mobile.bridge

import android.app.DatePickerDialog
import android.content.Intent
import android.provider.Settings
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.FragmentActivity
import app.cinquante.mobile.push.PushPermission
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeParseException

// Bridge components (lots 8b and 9). Each name matches a Stimulus controller in
// app/javascript/controllers/bridge/ (or confirm_dialog.js for « confirm »);
// the message shapes are documented there.

private val json = Json { encodeDefaults = true; explicitNulls = true }

/** Shared helpers: the hosting activity, and a reply with a serialisable body. */
abstract class CinquanteComponent(
    name: String,
    protected val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    protected val activity: FragmentActivity?
        get() = bridgeDelegate.destination.fragment.activity

    protected fun <T> reply(event: String, serializer: KSerializer<T>, data: T) {
        replyTo(event, json.encodeToString(serializer, data))
    }
}

// ---- push-notifications ------------------------------------------------------

@Serializable
data class PushStateReply(
    val permission: String,
    val token: String?,
    val platform: String = "android",
    val previousToken: String?
)

class PushNotificationsComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : CinquanteComponent(name, delegate) {

    override fun onReceive(message: Message) {
        val context = activity ?: return
        when (message.event) {
            // Every page load of a signed-in person: state only, never a prompt.
            "connect" -> PushPermission.state(context) { replyState(message.event, it) }
            // H1 « Activer »: the system prompt, then the new state.
            "request" -> PushPermission.request(context) {
                PushPermission.state(context) { replyState(message.event, it) }
            }
        }
    }

    private fun replyState(event: String, state: PushPermission.State) {
        reply(event, PushStateReply.serializer(), PushStateReply(state.permission, state.token, "android", state.previousToken))
    }
}

// ---- settings ------------------------------------------------------------------

class SettingsComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : CinquanteComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "open") return
        val context = activity ?: return
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        context.startActivity(intent)
    }
}

// ---- date-picker -----------------------------------------------------------------

@Serializable
data class DatePickerRequest(val value: String? = null, val min: String? = null, val max: String? = null)

@Serializable
data class DatePickerReply(val value: String)

class DatePickerComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : CinquanteComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "show") return
        val context = activity ?: return
        val data = message.data<DatePickerRequest>() ?: DatePickerRequest()
        val initial = parse(data.value) ?: LocalDate.now()

        val dialog = DatePickerDialog(
            context,
            { _, year, month, day -> reply("show", DatePickerReply.serializer(), DatePickerReply(LocalDate.of(year, month + 1, day).toString())) },
            initial.year, initial.monthValue - 1, initial.dayOfMonth
        )
        parse(data.min)?.let { dialog.datePicker.minDate = millis(it) }
        parse(data.max)?.let { dialog.datePicker.maxDate = millis(it) }
        dialog.show()
    }

    private fun parse(value: String?): LocalDate? = try {
        if (value.isNullOrBlank()) null else LocalDate.parse(value)
    } catch (_: DateTimeParseException) {
        null
    }

    private fun millis(date: LocalDate): Long =
        date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
}

// ---- overflow-menu -----------------------------------------------------------------

@Serializable
data class MenuItem(val title: String, val index: Int, val destructive: Boolean = false)

@Serializable
data class MenuRequest(val title: String? = null, val items: List<MenuItem> = emptyList())

@Serializable
data class MenuReply(val selectedIndex: Int)

class OverflowMenuComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : CinquanteComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "show") return
        val context = activity ?: return
        val data = message.data<MenuRequest>() ?: return
        if (data.items.isEmpty()) return

        AlertDialog.Builder(context)
            .setTitle(data.title)
            .setItems(data.items.map { it.title }.toTypedArray()) { _, which ->
                reply("show", MenuReply.serializer(), MenuReply(data.items[which].index))
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
}

// ---- confirm ---------------------------------------------------------------------------

@Serializable
data class ConfirmRequest(val message: String = "", val confirmLabel: String? = null, val cancelLabel: String? = null)

@Serializable
data class ConfirmReply(val confirmed: Boolean)

/**
 * Turbo's data-turbo-confirm as a native dialog. The two buttons have the same
 * weight, as on the web sheet (decision 2026-11-08).
 */
class ConfirmComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : CinquanteComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "show") return
        val context = activity ?: return
        val data = message.data<ConfirmRequest>() ?: return
        var answered = false
        val answer = { confirmed: Boolean ->
            if (!answered) {
                answered = true
                reply("show", ConfirmReply.serializer(), ConfirmReply(confirmed))
            }
        }

        AlertDialog.Builder(context)
            .setMessage(data.message)
            .setPositiveButton(data.confirmLabel ?: context.getString(android.R.string.ok)) { _, _ -> answer(true) }
            .setNegativeButton(data.cancelLabel ?: context.getString(android.R.string.cancel)) { _, _ -> answer(false) }
            .setOnCancelListener { answer(false) }
            .show()
    }
}
