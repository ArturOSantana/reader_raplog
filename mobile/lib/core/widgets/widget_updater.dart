import 'package:home_widget/home_widget.dart';
import 'widget_keys.dart';

/// Utilitário de baixo nível para persistir dados individuais nos
/// SharedPreferences/UserDefaults nativos que os widgets lêem.
///
/// Use [WidgetManager] em vez desta classe diretamente.
abstract final class WidgetUpdater {
  /// Salva um único valor e, opcionalmente, força a atualização do widget.
  static Future<void> save<T>(String key, T value) async {
    await HomeWidget.saveWidgetData<T>(key, value);
  }

  /// Aciona a re-renderização de todos os widgets Android/iOS registrados.
  static Future<void> updateAll() async {
    await HomeWidget.updateWidget(
      androidName: WidgetKeys.androidStreakWidget,
      iOSName: WidgetKeys.iosStreakWidget,
      qualifiedAndroidName:
          'com.readlog.readlog.widgets.${WidgetKeys.androidStreakWidget}',
    );
    await HomeWidget.updateWidget(
      androidName: WidgetKeys.androidCurrentBookWidget,
      iOSName: WidgetKeys.iosCurrentBookWidget,
      qualifiedAndroidName:
          'com.readlog.readlog.widgets.${WidgetKeys.androidCurrentBookWidget}',
    );
    await HomeWidget.updateWidget(
      androidName: WidgetKeys.androidDailyGoalWidget,
      iOSName: WidgetKeys.iosDailyGoalWidget,
      qualifiedAndroidName:
          'com.readlog.readlog.widgets.${WidgetKeys.androidDailyGoalWidget}',
    );
    await HomeWidget.updateWidget(
      androidName: WidgetKeys.androidQuoteWidget,
      iOSName: WidgetKeys.iosQuoteWidget,
      qualifiedAndroidName:
          'com.readlog.readlog.widgets.${WidgetKeys.androidQuoteWidget}',
    );
    await HomeWidget.updateWidget(
      androidName: WidgetKeys.androidClubWidget,
      iOSName: WidgetKeys.iosClubWidget,
      qualifiedAndroidName:
          'com.readlog.readlog.widgets.${WidgetKeys.androidClubWidget}',
    );
    await HomeWidget.updateWidget(
      androidName: WidgetKeys.androidDashboardWidget,
      iOSName: WidgetKeys.iosDashboardWidget,
      qualifiedAndroidName:
          'com.readlog.readlog.widgets.${WidgetKeys.androidDashboardWidget}',
    );
  }
}
