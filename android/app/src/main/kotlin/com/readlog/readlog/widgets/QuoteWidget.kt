package com.readlog.readlog.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import com.readlog.readlog.R
import es.antonborri.home_widget.HomeWidgetPlugin

class QuoteWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)

            val quote = widgetData.getString("quote", "") ?: ""
            val author = widgetData.getString("quoteAuthor", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_quote)
            views.setTextViewText(R.id.tv_quote_text, "\u201c$quote\u201d")
            views.setTextViewText(R.id.tv_quote_author, author)

            val intent = Intent(context, Class.forName("com.readlog.readlog.MainActivity"))
            intent.action = "OPEN_HOME"
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 300,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_quote_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
