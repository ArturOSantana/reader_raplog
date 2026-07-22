package com.readlog.readlog.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import com.readlog.readlog.R
import es.antonborri.home_widget.HomeWidgetPlugin

class DailyGoalWidget : AppWidgetProvider() {

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

            val current = widgetData.getInt("dailyGoal", 0)
            val target = widgetData.getInt("dailyGoalTarget", 0)
            val progress = widgetData.getFloat("dailyGoalProgress", 0f)
            val percent = (progress * 100).toInt()

            val views = RemoteViews(context.packageName, R.layout.widget_daily_goal)
            views.setTextViewText(R.id.tv_goal_progress, "$current / $target páginas")
            views.setProgressBar(R.id.pb_goal_progress, 100, percent, false)

            val intent = Intent(context, Class.forName("com.readlog.readlog.MainActivity"))
            intent.action = "OPEN_SESSION"
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 200,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_goal_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
