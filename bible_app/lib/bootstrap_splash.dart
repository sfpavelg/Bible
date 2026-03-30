import 'package:flutter/material.dart';

/// Экран до окончания [AppProvider.initializeApp] — тот же фон и лого, что нативный splash Android.
class BootstrapSplash extends StatelessWidget {
  const BootstrapSplash({super.key});

  static const _bg = Color(0xFFE1F5FE);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    int? cacheSide;
    if (mq != null) {
      final logicalW = (mq.size.width - 96).clamp(100.0, 360.0);
      cacheSide =
          (logicalW * mq.devicePixelRatio).round().clamp(256, 640);
    }
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Image.asset(
            'assets/branding/launch_logo.png',
            fit: BoxFit.contain,
            cacheWidth: cacheSide,
            cacheHeight: cacheSide,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
