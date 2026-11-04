package it.casamichela.app

import android.graphics.Rect
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.view.View
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

const val TEXT_MENU_CHANNEL = "it.casamichela.app/text_menu"

// The floating menu of native text; Flutter draws its own copy of it on Android.
class TextMenu(
    private val channel: MethodChannel,
    private val view: () -> View?,
) : ActionMode.Callback2() {
    private var mode: ActionMode? = null
    private var labels: List<String> = emptyList()
    private val anchor = Rect()

    fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                anchor.set(
                    call.argument<Number>("left")?.toInt() ?: 0,
                    call.argument<Number>("top")?.toInt() ?: 0,
                    call.argument<Number>("right")?.toInt() ?: 0,
                    call.argument<Number>("bottom")?.toInt() ?: 0,
                )
                show(call.argument<List<String>>("labels").orEmpty())
                result.success(null)
            }
            "hide" -> {
                hide()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun show(newLabels: List<String>) {
        val open = mode
        val relabelled = newLabels != labels

        labels = newLabels

        when {
            open == null -> mode = view()?.startActionMode(this, ActionMode.TYPE_FLOATING)
            relabelled -> open.invalidate()
            else -> open.invalidateContentRect()
        }
    }

    private fun hide() {
        val open = mode ?: return

        mode = null
        open.finish()
    }

    override fun onCreateActionMode(mode: ActionMode, menu: Menu) = true

    override fun onPrepareActionMode(mode: ActionMode, menu: Menu): Boolean {
        menu.clear()

        labels.forEachIndexed { index, label ->
            menu.add(Menu.NONE, index, index, label).setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
        }

        return true
    }

    override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
        channel.invokeMethod("pressed", item.itemId)
        return true
    }

    // hide() has already let go of a menu Flutter closed itself.
    override fun onDestroyActionMode(mode: ActionMode) {
        if (this.mode === mode) {
            this.mode = null
            channel.invokeMethod("closed", null)
        }
    }

    override fun onGetContentRect(mode: ActionMode, view: View, outRect: Rect) {
        outRect.set(anchor)
    }
}
