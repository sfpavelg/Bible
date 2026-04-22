import 'dart:async';
import 'dart:convert';

import 'package:bible_app/journal/parallel_reading_plan_data.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/notebook_chrome_dialog_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Снимает один маршрут с навигатора не более одного раза (двойной клик не уводит
/// со стека экран под диалогом — чёрный экран).
class _PopRouteOnce extends StatefulWidget {
  const _PopRouteOnce({
    required this.navigatorContext,
    required this.builder,
  });

  final BuildContext navigatorContext;
  final Widget Function(BuildContext context, VoidCallback popOnce) builder;

  @override
  State<_PopRouteOnce> createState() => _PopRouteOnceState();
}

class _PopRouteOnceState extends State<_PopRouteOnce> {
  bool _used = false;

  void _popOnce() {
    if (_used) return;
    _used = true;
    final c = widget.navigatorContext;
    if (c.mounted && Navigator.of(c).canPop()) {
      Navigator.pop(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _popOnce);
  }
}

/// Деления на ползунках настроек — короткие вертикальные линии вместо круглых точек.
class _SettingsSliderVerticalTickMarkShape extends SliderTickMarkShape {
  const _SettingsSliderVerticalTickMarkShape();

  static const double _lineWidth = 1.2;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    final th = sliderTheme.trackHeight ?? 4.0;
    final h = (th * 2.0).clamp(6.0, 10.0);
    return Size(_lineWidth, h);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    required bool isEnabled,
  }) {
    assert(sliderTheme.disabledActiveTickMarkColor != null);
    assert(sliderTheme.disabledInactiveTickMarkColor != null);
    assert(sliderTheme.activeTickMarkColor != null);
    assert(sliderTheme.inactiveTickMarkColor != null);
    final double xOffset = center.dx - thumbCenter.dx;
    final (Color? begin, Color? end) = switch (textDirection) {
      TextDirection.ltr when xOffset > 0 => (
          sliderTheme.disabledInactiveTickMarkColor,
          sliderTheme.inactiveTickMarkColor,
        ),
      TextDirection.rtl when xOffset < 0 => (
          sliderTheme.disabledInactiveTickMarkColor,
          sliderTheme.inactiveTickMarkColor,
        ),
      TextDirection.ltr || TextDirection.rtl => (
          sliderTheme.disabledActiveTickMarkColor,
          sliderTheme.activeTickMarkColor,
        ),
    };
    final paint = Paint()
      ..color = ColorTween(begin: begin, end: end).evaluate(enableAnimation)!;
    final sz = getPreferredSize(isEnabled: isEnabled, sliderTheme: sliderTheme);
    context.canvas.drawRect(
      Rect.fromCenter(center: center, width: sz.width, height: sz.height),
      paint,
    );
  }
}

/// Публичный JSON с информацией о последней версии.
/// Формат (пример):
/// {
///   "version_name": "1.1.0",
///   "version_code": 2,
///   "apk_url": "https://....apk",
///   "changes": ["...", "..."]
/// }
///
/// После загрузки `latest.json` в Google Drive замените FILE_ID_JSON на ID файла:
/// https://drive.google.com/file/d/FILE_ID_JSON/view
const String _releaseManifestUrl =
    'https://drive.google.com/uc?export=download&id=1QGINCs2h6GSbgLLIlrH749gTRRA6sCmV';

class _SupportChangelogEntry {
  const _SupportChangelogEntry({
    required this.versionName,
    required this.versionCode,
    required this.date,
    required this.changes,
  });

  final String versionName;
  final int versionCode;
  final String date;
  final List<String> changes;

  String get fullVersion => '$versionName+$versionCode';
}

class _SupportRemoteRelease {
  const _SupportRemoteRelease({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.changes,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;
  final List<String> changes;
}

class _SupportDialogData {
  const _SupportDialogData({
    required this.packageInfo,
    required this.changelog,
  });

  final PackageInfo packageInfo;
  final List<_SupportChangelogEntry> changelog;
}

int _versionCodeFromPackageVersion(String version) {
  final plus = version.lastIndexOf('+');
  if (plus < 0 || plus == version.length - 1) return 0;
  return int.tryParse(version.substring(plus + 1)) ?? 0;
}

String _versionNameFromPackageVersion(String version) {
  final plus = version.lastIndexOf('+');
  if (plus < 0) return version;
  return version.substring(0, plus);
}

Future<List<_SupportChangelogEntry>> _loadSupportChangelog() async {
  try {
    final raw = await rootBundle.loadString('assets/version/changelog.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['versions'] as List<dynamic>? ?? const []);
    final out = <_SupportChangelogEntry>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final versionName = (m['version_name'] ?? '').toString().trim();
      final versionCode = (m['version_code'] as num?)?.toInt() ?? 0;
      final date = (m['date'] ?? '').toString().trim();
      final changes = (m['changes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      if (versionName.isEmpty || versionCode <= 0) continue;
      out.add(
        _SupportChangelogEntry(
          versionName: versionName,
          versionCode: versionCode,
          date: date,
          changes: changes,
        ),
      );
    }
    return out;
  } catch (_) {
    return const [];
  }
}

Future<_SupportRemoteRelease?> _fetchSupportRemoteRelease() async {
  final manifestUrl = _releaseManifestUrl.trim();
  if (manifestUrl.isEmpty || manifestUrl.contains('FILE_ID_JSON')) return null;
  final uri = Uri.parse(manifestUrl);
  final response = await http.get(uri).timeout(const Duration(seconds: 8));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('HTTP ${response.statusCode}');
  }
  final decoded =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  final versionName = (decoded['version_name'] ?? decoded['versionName'] ?? '')
      .toString()
      .trim();
  final dynamic rawVersionCode =
      decoded['version_code'] ?? decoded['versionCode'];
  final versionCode = rawVersionCode is num ? rawVersionCode.toInt() : 0;
  final apkUrl =
      (decoded['apk_url'] ?? decoded['apkUrl'] ?? '').toString().trim();
  final changes = (decoded['changes'] as List<dynamic>? ?? const [])
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (versionName.isEmpty || versionCode <= 0 || apkUrl.isEmpty) {
    throw StateError('Неверный формат release manifest');
  }
  return _SupportRemoteRelease(
    versionName: versionName,
    versionCode: versionCode,
    apkUrl: apkUrl,
    changes: changes,
  );
}

Future<_SupportDialogData> _loadSupportDialogData() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final changelog = await _loadSupportChangelog();
  return _SupportDialogData(
    packageInfo: packageInfo,
    changelog: changelog,
  );
}

String _friendlySupportUpdateError(Object e) {
  final raw = e.toString();
  if (raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('No address associated with hostname')) {
    return 'Нет подключения к сети.';
  }
  if (raw.contains('TimeoutException')) {
    return 'Сервер обновлений не отвечает. Попробуйте позже.';
  }
  return 'Не удалось проверить обновление.';
}

/// Краткое предупреждение на время вызова системы (пока [launchUrl] и переключение
/// в браузер/установщик); без кнопки — закрывается само после передачи ссылки ОС.
Future<void> _openApkDownloadUrl(
  BuildContext context,
  String url, {
  String errorMessage = 'Не удалось открыть ссылку APK',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final uri = Uri.parse(url);
          final ok = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!dialogContext.mounted) return;
          if (!ok) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        } finally {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        }
      });
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: scheme.surface,
          content: Text(
            'Работает менеджер установки операционной системы, следуйте командам.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
          ),
        ),
      );
    },
  );
}

void showAppSettingsDialog(BuildContext context) {
  final appProvider = Provider.of<AppProvider>(context, listen: false);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      ThemeMode selectedTheme = appProvider.themeMode;
      double fontSize = appProvider.fontSize;
      double lineHeight = appProvider.lineHeight;
      double verseSpacing = appProvider.verseSpacing;
      bool showSeptuagintText = appProvider.showSeptuagintText;
      bool keepScreenOn = appProvider.keepScreenOn;
      String fontPreset = appProvider.verseFontPreset;
      if (!AppProvider.verseFontLabels.containsKey(fontPreset)) {
        fontPreset = 'sans';
      }
      double chromeBtnSize = appProvider.chromeButtonSize;

      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Consumer<AppProvider>(
            builder: (consumerContext, _, __) {
              // Держим локальное значение в синхроне с провайдером, чтобы якорь и
              // геометрия панели пересчитывались сразу при изменении размера кнопок.
              chromeBtnSize = appProvider.chromeButtonSize;
              final theme = Theme.of(consumerContext);
              final scheme = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final settingsBg =
                  isDark ? const Color(0xFF37474F) : const Color(0xFFE1F5FE);

              final uiFs = fontSize.clamp(12.0, 28.0);
              final kSettingsTitleStyle = TextStyle(
                fontSize: (uiFs * 1.25).clamp(16.0, 32.0),
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              );
              final kSettingsHeadingStyle = TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: (uiFs * 0.9).clamp(12.0, 26.0),
                color: scheme.onSurface,
              );
              final kSettingsBodyStyle = TextStyle(
                fontSize: uiFs,
                color: scheme.onSurface,
              );
              final kSettingsSegmentTextStyle = TextStyle(
                fontSize: (uiFs * 0.92).clamp(12.0, 24.0),
              );
              const kSegIcon = 18.0;
              final dropdownHeight = chromeBtnSize < kMinInteractiveDimension
                  ? kMinInteractiveDimension
                  : chromeBtnSize;

              SliderThemeData sliderDecor(SliderThemeData base) =>
                  base.copyWith(
                    activeTrackColor: scheme.primary,
                    inactiveTrackColor: isDark
                        ? scheme.surfaceContainerHighest
                        : Colors.blue.shade100,
                    thumbColor: scheme.primary,
                    overlayColor: scheme.primary.withValues(alpha: 0.12),
                    tickMarkShape: const _SettingsSliderVerticalTickMarkShape(),
                    activeTickMarkColor:
                        isDark ? scheme.primary : Colors.blue.shade900,
                    inactiveTickMarkColor: isDark
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : Colors.blue.shade600,
                    disabledActiveTickMarkColor: Colors.grey.shade600,
                    disabledInactiveTickMarkColor: Colors.grey.shade500,
                  );

              final panelWidth =
                  ((MediaQuery.sizeOf(consumerContext).width - 12) * (2 / 3))
                      .clamp(300.0, 362.5);
              final topAnchor = MediaQuery.paddingOf(consumerContext).top +
                  AppProvider.toolbarHeightForChrome(chromeBtnSize);
              final maxBodyHeight =
                  (MediaQuery.sizeOf(consumerContext).height - topAnchor - 24)
                      .clamp(220.0, 640.0);

              return Stack(
                children: [
                  Positioned(
                    top: topAnchor,
                    right: 0,
                    child: SizedBox(
                      width: panelWidth,
                      child: Material(
                        color: settingsBg,
                        elevation: 10,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Настройки',
                                      style: kSettingsTitleStyle,
                                    ),
                                  ),
                                  _PopRouteOnce(
                                    navigatorContext: modalContext,
                                    builder: (c, popOnce) =>
                                        NotebookChromeDialogCloseButton(
                                      onPressed: popOnce,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxHeight: maxBodyHeight),
                                child: SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.fromLTRB(2, 2, 2, 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Размер шрифта',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      SliderTheme(
                                        data: sliderDecor(
                                            SliderTheme.of(consumerContext)),
                                        child: Slider(
                                          padding: EdgeInsets.zero,
                                          value: fontSize.clamp(12.0, 28.0),
                                          min: 12.0,
                                          max: 28.0,
                                          divisions: 16,
                                          label: fontSize.toStringAsFixed(0),
                                          onChanged: (value) {
                                            setModalState(
                                                () => fontSize = value);
                                            appProvider.changeFontSize(value);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Межстрочный интервал',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      SliderTheme(
                                        data: sliderDecor(
                                            SliderTheme.of(consumerContext)),
                                        child: Slider(
                                          padding: EdgeInsets.zero,
                                          value: lineHeight.clamp(1.0, 2.2),
                                          min: 1.0,
                                          max: 2.2,
                                          divisions: 12,
                                          label: lineHeight.toStringAsFixed(2),
                                          onChanged: (value) {
                                            setModalState(
                                                () => lineHeight = value);
                                            appProvider.changeLineHeight(value);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Интервал между стихами',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      SliderTheme(
                                        data: sliderDecor(
                                            SliderTheme.of(consumerContext)),
                                        child: Slider(
                                          padding: EdgeInsets.zero,
                                          value: verseSpacing.clamp(0.0, 28.0),
                                          min: 0.0,
                                          max: 28.0,
                                          divisions: 28,
                                          label:
                                              verseSpacing.toStringAsFixed(0),
                                          onChanged: (value) {
                                            setModalState(
                                                () => verseSpacing = value);
                                            appProvider
                                                .changeVerseSpacing(value);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Шрифт текста',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: dropdownHeight,
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          isDense: true,
                                          itemHeight: dropdownHeight,
                                          value: fontPreset,
                                          style: kSettingsBodyStyle,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: scheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.75),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: ChromeOutline.side,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: ChromeOutline.side,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  ChromeOutline.side.copyWith(
                                                width:
                                                    ChromeOutline.width + 0.3,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 0,
                                            ),
                                          ),
                                          items: AppProvider
                                              .verseFontLabels.entries
                                              .map(
                                                (e) => DropdownMenuItem<String>(
                                                  value: e.key,
                                                  child: Text(
                                                    e.value,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: kSettingsBodyStyle,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setModalState(
                                                () => fontPreset = value);
                                            appProvider
                                                .setVerseFontPreset(value);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Размер кнопок',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      SliderTheme(
                                        data: sliderDecor(
                                            SliderTheme.of(consumerContext)),
                                        child: Slider(
                                          padding: EdgeInsets.zero,
                                          value: chromeBtnSize.clamp(
                                            AppProvider.chromeButtonSizeMin,
                                            AppProvider.chromeButtonSizeMax,
                                          ),
                                          min: AppProvider.chromeButtonSizeMin,
                                          max: AppProvider.chromeButtonSizeMax,
                                          divisions: 24,
                                          label:
                                              chromeBtnSize.round().toString(),
                                          onChanged: (value) {
                                            setModalState(
                                                () => chromeBtnSize = value);
                                            appProvider
                                                .changeChromeButtonSize(value);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Тема',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      SegmentedButton<ThemeMode>(
                                        segments: <ButtonSegment<ThemeMode>>[
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.light,
                                            label: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                'Светлая',
                                                maxLines: 1,
                                                softWrap: false,
                                                style:
                                                    kSettingsSegmentTextStyle,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.light_mode_outlined,
                                              size: kSegIcon,
                                            ),
                                          ),
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.dark,
                                            label: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                'Тёмная',
                                                maxLines: 1,
                                                softWrap: false,
                                                style:
                                                    kSettingsSegmentTextStyle,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.dark_mode_outlined,
                                              size: kSegIcon,
                                            ),
                                          ),
                                        ],
                                        style: SegmentedButton.styleFrom(
                                          textStyle: kSettingsSegmentTextStyle,
                                        ).copyWith(
                                          backgroundColor: WidgetStateProperty
                                              .resolveWith<Color?>(
                                            (states) {
                                              if (states.contains(
                                                  WidgetState.selected)) {
                                                return scheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.75);
                                              }
                                              return null;
                                            },
                                          ),
                                          side: const WidgetStatePropertyAll(
                                            ChromeOutline.side,
                                          ),
                                        ),
                                        selected: <ThemeMode>{selectedTheme},
                                        onSelectionChanged:
                                            (Set<ThemeMode> next) {
                                          if (next.isEmpty) return;
                                          final m = next.first;
                                          setModalState(
                                              () => selectedTheme = m);
                                          appProvider.setThemeMode(m);
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      SwitchListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          'Септуагинта [ ]',
                                          style: kSettingsBodyStyle,
                                        ),
                                        value: showSeptuagintText,
                                        activeThumbColor: scheme.primary,
                                        onChanged: (value) {
                                          setModalState(
                                            () => showSeptuagintText = value,
                                          );
                                          appProvider
                                              .setShowSeptuagintText(value);
                                        },
                                      ),
                                      SwitchListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          'Не выключать экран',
                                          style: kSettingsBodyStyle,
                                        ),
                                        value: keepScreenOn,
                                        activeThumbColor: scheme.primary,
                                        onChanged: (value) async {
                                          setModalState(
                                              () => keepScreenOn = value);
                                          await appProvider
                                              .setKeepScreenOn(value);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) =>
        FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    ),
  );
}

void showAppSupportDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (routeContext) {
      final theme = Theme.of(routeContext);
      final scheme = theme.colorScheme;
      final app = routeContext.watch<AppProvider>();
      final body = theme.textTheme.bodyMedium!.copyWith(
        color: scheme.onSurface,
        fontSize: app.fontSize,
        height: app.lineHeight,
      );
      final chrome = app.chromeButtonSize;
      final copyIcon = (chrome * 0.5).clamp(18.0, 30.0);
      return FutureBuilder<_SupportDialogData>(
        future: _loadSupportDialogData(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return AlertDialog(
              backgroundColor: scheme.surface,
              title: Text(
                'Техподдержка',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: scheme.onSurface),
              ),
              content: const SizedBox(
                width: 320,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            );
          }

          final data = snapshot.data;
          final currentVersion = data?.packageInfo.version ??
              _versionNameFromPackageVersion('0.0.0+0');
          final currentBuild = data?.packageInfo.buildNumber ??
              _versionCodeFromPackageVersion('0.0.0+0').toString();
          final currentCode = int.tryParse(currentBuild) ??
              _versionCodeFromPackageVersion('$currentVersion+$currentBuild');

          final supportPayload = 'Автор проекта: Софеин Павел Геннадьевич\n'
              'Контактная почта: sfpavelg@gmail.com\n'
              'Версия проекта: $currentVersion+$currentBuild';

          _SupportRemoteRelease? remoteRelease;
          String? remoteError;
          var isChecking = false;
          var hasChecked = false;

          return StatefulBuilder(
            builder: (modalContext, setModalState) {
              final hasRemote = remoteRelease != null;
              final hasUpdate =
                  hasRemote && remoteRelease!.versionCode > currentCode;

              return AlertDialog(
                backgroundColor: scheme.surface,
                titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Техподдержка',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    _PopRouteOnce(
                      navigatorContext: routeContext,
                      builder: (c, popOnce) =>
                          NotebookChromeDialogCloseButton(onPressed: popOnce),
                    ),
                  ],
                ),
                content: DefaultTextStyle(
                  style: body,
                  child: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Автор проекта:'),
                          const SizedBox(height: 4),
                          Text(
                            'Софеин Павел Геннадьевич',
                            style: body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          const Text('Контактная почта:'),
                          const SizedBox(height: 4),
                          Text(
                            'sfpavelg@gmail.com',
                            style: body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Версия приложения: $currentVersion+$currentBuild',
                            style: body.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding:
                                const EdgeInsets.only(left: 4, right: 4),
                            title: const Text('История версий'),
                            subtitle: Text(
                              data != null && data.changelog.isNotEmpty
                                  ? 'Нажмите, чтобы посмотреть изменения'
                                  : 'Пока нет записей',
                            ),
                            children: [
                              if (data != null && data.changelog.isNotEmpty)
                                for (final v in data.changelog)
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding: const EdgeInsets.only(
                                        left: 6, bottom: 6),
                                    title: Text(v.fullVersion),
                                    subtitle: Text(v.date),
                                    children: [
                                      for (final ch in v.changes)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text('• $ch'),
                                        ),
                                    ],
                                  ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Обновление',
                            style: body.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: isChecking
                                ? null
                                : () async {
                                    setModalState(() {
                                      isChecking = true;
                                      remoteError = null;
                                    });
                                    try {
                                      final remote =
                                          await _fetchSupportRemoteRelease();
                                      setModalState(() {
                                        remoteRelease = remote;
                                        hasChecked = true;
                                        isChecking = false;
                                      });
                                    } catch (e) {
                                      setModalState(() {
                                        remoteRelease = null;
                                        remoteError =
                                            _friendlySupportUpdateError(e);
                                        hasChecked = true;
                                        isChecking = false;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.sync),
                            label: Text(
                              isChecking
                                  ? 'Проверяем...'
                                  : 'Проверить обновление',
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!hasChecked)
                            const Text(
                                'Нажмите кнопку для проверки обновления.')
                          else if (remoteError != null)
                            Text(
                              remoteError!,
                              style:
                                  body.copyWith(color: Colors.orange.shade700),
                            )
                          else if (hasRemote && hasUpdate) ...[
                            Text(
                              'Доступна новая версия: ${remoteRelease!.versionName}+${remoteRelease!.versionCode}',
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => unawaited(
                                _openApkDownloadUrl(
                                  routeContext,
                                  remoteRelease!.apkUrl,
                                ),
                              ),
                              icon: const Icon(Icons.system_update_alt),
                              label: const Text('Скачать обновление'),
                            ),
                            if (remoteRelease!.changes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding:
                                    const EdgeInsets.only(left: 4, right: 4),
                                title: const Text('Описание обновления'),
                                subtitle: const Text(
                                  'Нажмите, чтобы посмотреть список изменений',
                                ),
                                children: [
                                  for (final ch in remoteRelease!.changes)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Text('• $ch'),
                                    ),
                                ],
                              ),
                            ],
                          ] else
                            const Text('Установлена актуальная версия'),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  Material(
                    color: NotebookChromeUi.secondaryButtonBackground(
                        routeContext),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: ChromeOutline.side,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: supportPayload),
                        );
                        if (!routeContext.mounted) return;
                        ScaffoldMessenger.of(routeContext).showSnackBar(
                          const SnackBar(
                            content: Text('Данные техподдержки скопированы'),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: chrome,
                        height: chrome,
                        child: Icon(
                          Icons.copy_all,
                          size: copyIcon,
                          color: NotebookChromeUi.secondaryButtonForeground(
                              routeContext),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

/// Заголовки разделов в окне «Помощь» (оглавление).
const TextStyle _helpDialogTocStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontStyle: FontStyle.italic,
);

void showAppHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (routeContext) {
      final theme = Theme.of(routeContext);
      final scheme = theme.colorScheme;
      final app = routeContext.watch<AppProvider>();
      final fs = app.fontSize;
      final lh = app.lineHeight;
      final tocStyle = _helpDialogTocStyle.copyWith(
        color: scheme.onSurface,
        fontSize: (fs * 0.95).clamp(12.0, 26.0),
        height: lh,
      );
      final bodyStyle = theme.textTheme.bodyMedium!.copyWith(
        color: scheme.onSurface,
        fontSize: fs,
        height: lh,
      );
      final n = kParallelReadingPlan365.length;
      final helpMaxH = MediaQuery.sizeOf(routeContext).height * 0.65;
      return AlertDialog(
        backgroundColor: scheme.surface,
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Помощь',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: scheme.onSurface),
              ),
            ),
            _PopRouteOnce(
              navigatorContext: routeContext,
              builder: (c, popOnce) =>
                  NotebookChromeDialogCloseButton(onPressed: popOnce),
            ),
          ],
        ),
        content: DefaultTextStyle(
          style: bodyStyle,
          child: SizedBox(
            width: 360,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: helpMaxH),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Библия:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Навигация',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Книгу и главу выбирают кнопки в верхней полосе.',
                    ),
                    Text(
                      '• Листать главу за главой можно жестом влево или вправо.',
                    ),
                    Text(
                      '• Долгое касание стиха включает выделение; коротким касанием отмечают ещё стихи.',
                    ),
                    Text(
                      '• «Избранное» в шапке сохраняет выбранные стихи и открывает их перечень.',
                    ),
                    Text(
                      '• В окнах выбора книги или главы закрыть подсказку можно кнопкой в углу заголовка.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Поиск',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Введите одно слово или несколько и нажмите «Найти».',
                    ),
                    Text(
                      '• Флажки «ВЗ» и «НЗ» ограничивают поиск Ветхим или Новым Заветом.',
                    ),
                    Text(
                      '• При включённом «Целом слове» находятся только отдельные слова целиком; '
                      'если выключить, подойдёт и вхождение внутри слова '
                      '(например, по «рад» откроется и «радость»).',
                    ),
                    Text(
                      '• По строке из списка результатов открывается соответствующий стих.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Блокнот:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Список файлов и папок:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Стрелка «Назад» слева в папке возвращает к внешнему списку.',
                    ),
                    Text(
                      '• «Новая папка» создаёт каталог там, где вы сейчас просматриваете список.',
                    ),
                    Text(
                      '• «Новый документ» — новая текстовая заметка; после создания откроется редактор.',
                    ),
                    Text(
                      '• Три точки справа в шапке открывают общее меню приложения '
                      '(настройки, помощь, выход и другое).',
                    ),
                    Text(
                      '• В настройках можно сменить тему, шрифт и интервалы в Библии, красные буквы, '
                      'величину кнопок панели и включить «Не выключать экран».',
                    ),
                    Text(
                      '• Короткое касание открывает файл или папку.',
                    ),
                    Text(
                      '• Долгое касание файла или папки открывает меню справа: для файла — '
                      'поделиться, сохранить копию, переименовать или удалить; '
                      'для папки — переименовать или удалить.',
                    ),
                    Text(
                      '• Перемещение файла: долгим касанием откройте меню файла, выберите '
                      '«Переместить в…», затем перейдите в нужную папку в дереве и нажмите '
                      '«Переместить сюда». Исходная папка отмечена серым цветом.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Редактор документа:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• «Закрыть» (стрелка) — сохранить изменения и вернуться к списку.',
                    ),
                    Text(
                      '• После паузы в наборе текст автоматически записывается на диск; '
                      'кнопка «Сохранить» в шапке сохраняет немедленно.',
                    ),
                    Text(
                      '• «Шаг назад» и «Шаг вперёд» отменяют или возвращают последние правки в тексте.',
                    ),
                    Text(
                      '• В списке при входе в папку внизу показана строка «Папка:» — путь от корня блокнота; '
                      'по сегментам пути можно нажимать и быстро переходить в выбранную папку '
                      '(с возвратом на нужный уровень).',
                    ),
                    Text(
                      '• В редакторе строка «Документ:» внизу напоминает полный путь к заметке, '
                      'со всеми вложенными папками.',
                    ),
                    Text(
                      '• Вертикальные три точки в шапке редактора ведут в то же общее меню приложения.',
                    ),
                    Text(
                      '• Текст набирается во всю ширину экрана; стихи из вкладки «Библия» можно '
                      'скопировать и вставить сюда.',
                    ),
                    Text(
                      '• После копирования и вставки буфер очищается автоматически — это защищает '
                      'от случайного повторного нажатия кнопки «Вставить».',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'План чтения:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Сначала показаны четыре квартала года; внутри каждого — подряд все дни '
                      'этой четверти. Номера дней сквозные, на весь год (1…$n). '
                      'На экране кварталов в шапке — выбор плана и меню; внутри квартала — прокрутка списка '
                      'и переход к началу или концу перечня.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Параллельный план',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ветхий Завет, Псалтирь и Новый Завет читаются рядом, по заранее выстроенному '
                      'порядку глав на каждый день. Нумерация дней идёт подряд (1…$n), без привязки к датам '
                      'календаря. Отметки «прочитано» хранятся на вашем устройстве.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Хронологический план',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Здесь порядок глав приближён к ходу событий и к сопутствующим текстам. '
                      'Дни снова идут подряд (1…$n), вне календарных дат. '
                      'Отметки «прочитано» не смешиваются с параллельным планом.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Последовательный план',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Все книги и главы Библии по каноническому порядку (от Бытия до Откровения) '
                      'равномерно распределены по $n дням. Отметки «прочитано» хранятся отдельно от '
                      'параллельного и хронологического планов.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
