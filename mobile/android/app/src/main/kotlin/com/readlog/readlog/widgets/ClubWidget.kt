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

class ClubWidget : AppWidgetProvider() {

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

            val clubName = widgetData.getString("clubName", "Clube do Livro") ?: "Clube do Livro"
            val bookTitle = widgetData.getString("clubBookTitle", "") ?: ""
            val nextMeeting = widgetData.getString("clubNextMeeting", "") ?: ""
            val meetingTime = widgetData.getString("clubNextMeetingTime", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_club)
            views.setTextViewText(R.id.tv_club_name, clubName)
            views.setTextViewText(R.id.tv_club_book, bookTitle)
            views.setTextViewText(R.id.tv_club_meeting, nextMeeting)
            views.setTextViewText(R.id.tv_club_time, meetingTime)

            val intent = Intent(context, MainActivity::class.java)
            intent.action = "OPEN_CLUBS"
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 400,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_club_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
