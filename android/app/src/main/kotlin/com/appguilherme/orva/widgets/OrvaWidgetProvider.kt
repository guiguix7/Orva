package com.appguilherme.orva.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.appguilherme.orva.MainActivity
import com.appguilherme.orva.R

const val WIDGET_ROUTE_EXTRA = "com.appguilherme.orva.widget.route"

/**
 * Shared lifecycle for the eight Orva widgets.
 *
 * The provider renders a previously validated snapshot and opens a validated
 * in-app destination. It never reads the database, runs domain rules or writes
 * user data. When the app lock is on, the snapshot itself carries no content.
 */
abstract class OrvaWidgetProvider : AppWidgetProvider() {
    abstract val layoutRes: Int
    abstract val route: String
    abstract val darkSurface: Boolean
    abstract fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, id))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, build(context, appWidgetId))
    }

    private fun build(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, layoutRes)
        views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context, widgetId))

        val snapshot = OrvaWidgetStore.snapshot(context)
        val locked = snapshot == null || snapshot.locked
        views.setViewVisibility(
            R.id.widget_locked,
            if (locked) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_content,
            if (locked) View.GONE else View.VISIBLE,
        )

        val titleColor = context.getColor(
            if (darkSurface) R.color.orva_widget_dark_text else R.color.orva_widget_text,
        )
        val bodyColor = context.getColor(
            if (darkSurface) R.color.orva_widget_dark_secondary else R.color.orva_widget_secondary,
        )
        views.setTextColor(R.id.widget_locked_title, titleColor)
        views.setTextColor(R.id.widget_locked_body, bodyColor)
        views.setTextColor(R.id.widget_updated, bodyColor)

        if (locked) {
            val protected = snapshot?.locked == true
            views.setTextViewText(
                R.id.widget_locked_title,
                if (protected) "Conteúdo protegido" else "Abra o Orva",
            )
            views.setTextViewText(
                R.id.widget_locked_body,
                if (protected) {
                    "Desbloqueie o app para ver seus dados."
                } else {
                    "Seus widgets aparecem após a primeira atualização."
                },
            )
        } else {
            bind(context, views, snapshot!!)
        }
        views.setTextViewText(R.id.widget_updated, OrvaWidgetStore.ageLabel(snapshot))
        return views
    }

    private fun launchIntent(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra(WIDGET_ROUTE_EXTRA, route)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

internal fun RemoteViews.text(id: Int, value: String?) {
    setTextViewText(id, value.orEmpty())
}

internal fun RemoteViews.visible(id: Int, isVisible: Boolean) {
    setViewVisibility(id, if (isVisible) View.VISIBLE else View.GONE)
}

internal fun RemoteViews.progress(id: Int, percent: Int?) {
    setProgressBar(id, 100, (percent ?: 0).coerceIn(0, 100), false)
}
