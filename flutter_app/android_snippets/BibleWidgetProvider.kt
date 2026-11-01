package PACKAGE_NAME

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BibleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.bible_widget)
            views.setTextViewText(R.id.w_title, widgetData.getString("title", "") ?: "")
            views.setTextViewText(R.id.w_body, widgetData.getString("body", "") ?: "")
            views.setTextViewText(R.id.w_streak, widgetData.getString("streak", "") ?: "")
            views.setTextViewText(R.id.w_pct, widgetData.getString("pct", "") ?: "")
            val intent = Intent(context, MainActivity::class.java)
            val pi = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.w_root, pi)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
