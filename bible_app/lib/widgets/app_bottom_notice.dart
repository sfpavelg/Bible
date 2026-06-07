import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/main_chrome_tab_bar.dart';
import 'package:flutter/material.dart';

/// Зазор между полоской и верхним краем панели вкладок.
const _kNoticeGapAboveTabBar = 4.0;

double _noticeBottomInset(BuildContext context) {
  return mainChromeTabBarTotalHeight(context) +
      MediaQuery.viewInsetsOf(context).bottom +
      _kNoticeGapAboveTabBar;
}

Widget _noticeBody(String message) {
  return Material(
    elevation: 0,
    color: BibleLightPalette.settingsGlassPrimary,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// Фиолетовая полоска над нижней навигацией (вкладки остаются нажимаемыми).
void showAppBottomNotice(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final bottom = _noticeBottomInset(rootContext);
  final overlay =
      Navigator.of(context, rootNavigator: true).overlay ??
          Overlay.maybeOf(context, rootOverlay: true);

  if (overlay == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: BibleLightPalette.settingsGlassPrimary,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(12, 0, 12, bottom),
      ),
    );
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: IgnorePointer(
        child: _noticeBody(message),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}
