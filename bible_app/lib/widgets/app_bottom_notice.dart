import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/main_chrome_tab_bar.dart';
import 'package:flutter/material.dart';

/// Фиолетовая полоска внизу экрана (над нижней навигацией), как в «Техподдержке».
void showAppBottomNotice(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: BibleLightPalette.settingsGlassPrimary,
        duration: duration,
      ),
    );
    return;
  }

  final bottom =
      mainChromeTabBarTotalHeight(context) + MediaQuery.viewInsetsOf(context).bottom;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Material(
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
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    entry.remove();
  });
}
