package com.appguilherme.orva.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/** Durable, app-private snapshot shared by every Orva widget provider. */
object OrvaWidgetStore {
    private const val PREFS = "orva_home_widgets"
    private const val KEY = "snapshot_v1"

    /** Validates before overwriting: a malformed payload keeps the last good one. */
    fun save(context: Context, raw: String): Boolean {
        if (WidgetSnapshot.parse(raw) == null) return false
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, raw)
            .apply()
        refreshAll(context)
        return true
    }

    fun snapshot(context: Context): WidgetSnapshot? = WidgetSnapshot.parse(
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null),
    )

    /** Asks every placed widget to redraw from the snapshot that just changed. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        for (provider in OrvaWidgetCatalog.providers) {
            val component = ComponentName(context, provider)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) continue
            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                this.component = component
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }

    /**
     * Honest freshness: the launcher may keep a snapshot for hours after the
     * app was last open, so the timestamp is always visible.
     */
    fun ageLabel(snapshot: WidgetSnapshot?): String {
        if (snapshot == null || snapshot.generatedAtMillis <= 0L) {
            return "Abra o Orva para atualizar"
        }
        val elapsedMinutes =
            ((System.currentTimeMillis() - snapshot.generatedAtMillis) / 60_000L)
                .coerceAtLeast(0L)
        val label = when {
            elapsedMinutes < 2 -> "Atualizado agora"
            elapsedMinutes < 60 -> "Atualizado há $elapsedMinutes min"
            elapsedMinutes < 24 * 60 -> "Atualizado há ${elapsedMinutes / 60} h"
            else -> "Atualizado há ${elapsedMinutes / (24 * 60)} d"
        }
        return if (elapsedMinutes >= 12 * 60) "$label · desatualizado" else label
    }
}

/** Every provider that participates in a snapshot refresh. */
object OrvaWidgetCatalog {
    val providers = listOf(
        TodayWidgetProvider::class.java,
        TasksWidgetProvider::class.java,
        ProgressWidgetProvider::class.java,
        ComparisonWidgetProvider::class.java,
        GoalsWidgetProvider::class.java,
        HabitsWidgetProvider::class.java,
        StudyWidgetProvider::class.java,
        AgendaWidgetProvider::class.java,
    )
}
