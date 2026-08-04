package com.readlog.readlog.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import com.readlog.readlog.R
import com.readlog.readlog.MainActivity
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget painel do leitor — reúne livro atual, meta, ofensiva, frase e clube.
 */
class ReaderDashboardWidget : AppWidgetProvider() {

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

            // Livro
            val bookTitle = widgetData.getString("currentBookTitle", "—") ?: "—"
            val currentPage = widgetData.getInt("currentPage", 0)
            val totalPages = widgetData.getInt("totalPages", 0)
            val bookProgress = widgetData.getFloat("readingProgress", 0f)

            // Ofensiva
            val streak = widgetData.getInt("streak", 0)

            // Meta
            val dailyGoal = widgetData.getInt("dailyGoal", 0)
            val dailyGoalTarget = widgetData.getInt("dailyGoalTarget", 0)
            val goalProgress = widgetData.getFloat("dailyGoalProgress", 0f)

            // Frase
            val quote = widgetData.getString("quote", "") ?: ""

            // Clube
            val nextMeeting = widgetData.getString("clubNextMeeting", "") ?: ""
            val meetingTime = widgetData.getString("clubNextMeetingTime", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_reader_dashboard)

            // Livro
            views.setTextViewText(R.id.tv_dash_book_title, bookTitle)
            val pagesText = if (totalPages > 0) "p. $currentPage/$totalPages" else "p. $currentPage"
            views.setTextViewText(R.id.tv_dash_book_pages, pagesText)
            views.setProgressBar(R.id.pb_dash_book, 100, (bookProgress * 100).toInt(), false)

            // Ofensiva
            views.setTextViewText(R.id.tv_dash_streak, "$streak dias")

            // Meta
            views.setTextViewText(R.id.tv_dash_goal, "$dailyGoal/$dailyGoalTarget pág.")
            views.setProgressBar(R.id.pb_dash_goal, 100, (goalProgress * 100).toInt(), false)

            // Frase
            views.setTextViewText(R.id.tv_dash_quote, quote)

            // Clube
            val meetingLabel = if (meetingTime.isNotEmpty()) "$nextMeeting · $meetingTime" else nextMeeting
            views.setTextViewText(R.id.tv_dash_club, meetingLabel)

            // Toque abre o app na home
            val intent = Intent(context, MainActivity::class.java)
            intent.action = "OPEN_HOME"
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 500,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_dashboard_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
