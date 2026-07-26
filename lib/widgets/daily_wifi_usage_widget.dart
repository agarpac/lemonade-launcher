import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailyWifiUsageWidget extends StatelessWidget {
  const DailyWifiUsageWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<NetworkService, SettingsService>(
      builder: (context, networkService, settingsService, _) {
        final localizations = AppLocalizations.of(context)!;

        if (!networkService.hasUsageStatsPermission) {
          return TextButton.icon(
             icon: const Icon(Icons.data_usage, size: 20),
             label: Text(localizations.wifiUsageGrantPermission),
             onPressed: () => networkService.requestPermission(),
          );
        }

        final period = settingsService.wifiUsagePeriod;
        String label;
        switch (period) {
          case 'weekly':
            label = '${localizations.wifiPeriodWeekly}: ';
            break;
          case 'monthly':
            label = '${localizations.wifiPeriodMonthly}: ';
            break;
          case 'daily':
          default:
            label = '${localizations.wifiPeriodDaily}: ';
            break;
        }

        return FutureBuilder<int>(
          future: networkService.getWifiUsageForPeriod(period),
          builder: (context, snapshot) {
            final usage = snapshot.data ?? networkService.dailyWifiUsage;
            final usageString = _formatBytes(usage);

            return RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
                  ],
                ),
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: usageString,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return "${d.toStringAsFixed(2)} ${suffixes[i]}";
  }
}
