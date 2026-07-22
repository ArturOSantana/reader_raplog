package com.readlog.readlog.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import com.readlog.readlog.R
import es.antonborri.home_widget.HomeWidgetPlugin

class CurrentBookWidget : AppWidgetProvider() {

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

            val title = widgetData.getString("currentBookTitle", "—") ?: "—"
            val author = widgetData.getString("currentBookAuthor", "") ?: ""
            val currentPage = widgetData.getInt("currentPage", 0)
            val totalPages = widgetData.getInt("totalPages", 0)
            val progress = widgetData.getFloat("readingProgress", 0f)
            val percent = (progress * 100).toInt()

            val views = RemoteViews(context.packageName, R.layout.widget_current_book)
            views.setTextViewText(R.id.tv_book_title, title)
            views.setTextViewText(R.id.tv_book_author, author)
            views.setTextViewText(R.id.tv_book_progress, "$percent%")
            if (totalPages > 0) {
                views.setTextViewText(R.id.tv_book_pages, "Página $currentPage de $totalPages")
            } else {
                views.setTextViewText(R.id.tv_book_pages, "Página $currentPage")
            }
            views.setProgressBar(R.id.pb_book_progress, 100, percent, false)

            val intent = Intent(context, Class.forName("com.readlog.readlog.MainActivity"))
            intent.action = "OPEN_SESSION"
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 100,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_book_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
