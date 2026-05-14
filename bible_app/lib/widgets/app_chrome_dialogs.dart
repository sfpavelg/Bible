import 'dart:async';
import 'dart:convert';

import 'package:bible_app/journal/faith_reading_plan_data.dart';
import 'package:bible_app/journal/love_reading_plan_data.dart';
import 'package:bible_app/journal/parallel_reading_plan_data.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/notebook_chrome_dialog_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Вариант светлой подложки боковых панелей.
enum ChromePanelLightSurface {
  /// «Стекло» на градиенте экрана (книга/глава, меню ⋯).
  chromeCardGlass,

  /// Настройки: плотный градиент без просвета внизу.
  settingsPanel,

  /// Техподдержка и инструкция: полностью непрозрачная плашка.
  modalOpaque,
}

/// Корпус боковых панелей «Настройки», «Техподдержка», «Инструкция».
Widget _chromePanelShell({
  required bool isDark,
  double borderRadius = 12,
  ChromePanelLightSurface lightSurface = ChromePanelLightSurface.chromeCardGlass,
  required Widget child,
}) {
  if (isDark) {
    return Material(
      color: const Color(0xFF37474F),
      elevation: 10,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
  final BoxDecoration decoration = switch (lightSurface) {
    ChromePanelLightSurface.settingsPanel =>
      BibleLightPalette.lightSettingsPanelDecoration(radius: borderRadius),
    ChromePanelLightSurface.modalOpaque =>
      BibleLightPalette.lightModalOpaquePanelDecoration(radius: borderRadius),
    ChromePanelLightSurface.chromeCardGlass =>
      BibleLightPalette.lightPanelShellDecoration(radius: borderRadius),
  };
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: DecoratedBox(
      decoration: decoration,
      child: child,
    ),
  );
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

/// Список изменений из manifest: массив строк или одна многострочная строка.
List<String> _manifestChangesList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
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
  final changes = _manifestChangesList(decoded['changes']);
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

Widget _supportChromeActionButton({
  required BuildContext context,
  required String label,
  required IconData icon,
  required VoidCallback? onTap,
}) {
  final chrome = context.watch<AppProvider>().chromeButtonSize;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final scheme = Theme.of(context).colorScheme;
  final iconSize = (chrome * 0.48).clamp(18.0, 30.0);
  final fontSize = (chrome * 0.32).clamp(12.0, 17.0);
  final fg = isDark
      ? NotebookChromeUi.secondaryButtonForeground(context)
      : BibleLightPalette.primaryText;
  final ic = isDark
      ? NotebookChromeUi.secondaryButtonForeground(context)
      : BibleLightPalette.iconActive;
  return Material(
    color: isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.75)
        : BibleLightPalette.activeBg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: isDark
          ? ChromeOutline.side
          : BibleLightPalette.chromePillOutlineSide,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: chrome),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (chrome * 0.38).clamp(10.0, 18.0),
            vertical: (chrome * 0.12).clamp(4.0, 8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ic, size: iconSize),
              SizedBox(width: (chrome * 0.2).clamp(6.0, 12.0)),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Предупреждение перед установщиком ОС: сначала показываем окно и держим его
/// на экране ~1.5 с, затем [launchUrl]; иначе в том же кадре открывается менеджер
/// и диалог не успевает отрисоваться.
Future<void> _openApkDownloadUrl(
  BuildContext context,
  String url, {
  String errorMessage = 'Не удалось открыть ссылку APK',
}) async {
  const installerHandoffPause = Duration(milliseconds: 1500);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await WidgetsBinding.instance.endOfFrame;
          await Future<void>.delayed(installerHandoffPause);
          if (!dialogContext.mounted) return;
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
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        } catch (_) {
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          content: Text(
            'Работает менеджер установки устройства, следуйте командам.',
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
    barrierDismissible: true,
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

              final uiFs = fontSize.clamp(12.0, 28.0);
              final textPrimary =
                  isDark ? scheme.onSurface : BibleLightPalette.primaryText;
              final kSettingsTitleStyle = TextStyle(
                fontSize: (uiFs * 1.25).clamp(16.0, 32.0),
                fontWeight: FontWeight.w600,
                color: textPrimary,
              );
              final kSettingsHeadingStyle = TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: (uiFs * 0.9).clamp(12.0, 26.0),
                color: textPrimary,
              );
              final kSettingsBodyStyle = TextStyle(
                fontSize: uiFs,
                color: textPrimary,
              );
              final kSettingsSegmentTextStyle = TextStyle(
                fontSize: (uiFs * 0.92).clamp(12.0, 24.0),
                color: textPrimary,
              );
              const kSegIcon = 18.0;
              const sliderHorizontalPadding = EdgeInsets.symmetric(horizontal: 8);
              final dropdownHeight = chromeBtnSize < kMinInteractiveDimension
                  ? kMinInteractiveDimension
                  : chromeBtnSize;

              SliderThemeData sliderDecor(SliderThemeData base) =>
                  base.copyWith(
                    activeTrackColor:
                        isDark ? scheme.primary : BibleLightPalette.primary,
                    inactiveTrackColor: isDark
                        ? scheme.surfaceContainerHighest
                        : BibleLightPalette.cardDivider,
                    thumbColor:
                        isDark ? scheme.primary : BibleLightPalette.primary,
                    overlayColor: BibleLightPalette.primary.withValues(alpha: 0.12),
                    tickMarkShape: const _SettingsSliderVerticalTickMarkShape(),
                    activeTickMarkColor: isDark
                        ? scheme.primary
                        : BibleLightPalette.primaryDark,
                    inactiveTickMarkColor: isDark
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : BibleLightPalette.secondaryText,
                    disabledActiveTickMarkColor: Colors.grey.shade600,
                    disabledInactiveTickMarkColor: Colors.grey.shade500,
                  );

              final mediaSize = MediaQuery.sizeOf(consumerContext);
              final mediaPadding = MediaQuery.paddingOf(consumerContext);
              final panelWidth =
                  ((mediaSize.width - 12) * (2 / 3)).clamp(300.0, 362.5);
              final topAnchor = mediaPadding.top +
                  AppProvider.toolbarHeightForChrome(chromeBtnSize);
              final bottomToolbarReserve =
                  AppProvider.toolbarHeightForChrome(chromeBtnSize);
              final maxBodyHeight = (mediaSize.height -
                      topAnchor -
                      bottomToolbarReserve -
                      mediaPadding.bottom -
                      92)
                  .clamp(140.0, 640.0)
                  .toDouble();

              return Stack(
                children: [
                  Positioned(
                    top: topAnchor,
                    right: 0,
                    child: SizedBox(
                      width: panelWidth,
                      child: _chromePanelShell(
                        isDark: isDark,
                        lightSurface: ChromePanelLightSurface.settingsPanel,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Настройки',
                                style: kSettingsTitleStyle,
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
                                          padding: sliderHorizontalPadding,
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
                                          padding: sliderHorizontalPadding,
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
                                          padding: sliderHorizontalPadding,
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
                                          dropdownColor: isDark
                                              ? scheme.surfaceContainerHighest
                                              : BibleLightPalette.modalPanelSolid,
                                          value: fontPreset,
                                          style: kSettingsBodyStyle,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: isDark
                                                ? scheme.surfaceContainerHighest
                                                    .withValues(alpha: 0.75)
                                                : BibleLightPalette.activeBg,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: isDark
                                                  ? ChromeOutline.side
                                                  : BibleLightPalette
                                                      .chromePillOutlineSide,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: isDark
                                                  ? ChromeOutline.side
                                                  : BibleLightPalette
                                                      .chromePillOutlineSide,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: (isDark
                                                      ? ChromeOutline.side
                                                      : BibleLightPalette
                                                          .chromePillOutlineSide)
                                                  .copyWith(
                                                width: ChromeOutline.width + 0.3,
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
                                          padding: sliderHorizontalPadding,
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
                                          selectedForegroundColor: isDark
                                              ? scheme.onSurface
                                              : BibleLightPalette.primary,
                                          selectedBackgroundColor: isDark
                                              ? scheme.surfaceContainerHighest
                                                  .withValues(alpha: 0.75)
                                              : BibleLightPalette.activeBg,
                                          foregroundColor: isDark
                                              ? scheme.onSurface
                                              : BibleLightPalette.secondaryText,
                                          backgroundColor: isDark
                                              ? scheme.surface
                                                  .withValues(alpha: 0.12)
                                              : BibleLightPalette.activeBg,
                                        ).copyWith(
                                          side: WidgetStatePropertyAll(
                                            isDark
                                                ? ChromeOutline.side
                                                : BibleLightPalette
                                                    .chromePillOutlineSide,
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
                                        activeTrackColor: isDark
                                            ? scheme.primary
                                            : BibleLightPalette.primary,
                                        activeThumbColor: Colors.white,
                                        inactiveTrackColor: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300,
                                        inactiveThumbColor: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade50,
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
                                        activeTrackColor: isDark
                                            ? scheme.primary
                                            : BibleLightPalette.primary,
                                        activeThumbColor: Colors.white,
                                        inactiveTrackColor: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300,
                                        inactiveThumbColor: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade50,
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

/// Геометрия правой панели хрома — как у окна «Настройки».
class _ChromePanelLayout {
  _ChromePanelLayout._(this.panelWidth, this.topAnchor, this.maxBodyHeight);

  factory _ChromePanelLayout.fromContext(
    BuildContext context,
    double chromeButtonSize,
  ) {
    final mediaSize = MediaQuery.sizeOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final panelWidth =
        ((mediaSize.width - 12) * (2 / 3)).clamp(300.0, 362.5);
    final topAnchor = mediaPadding.top +
        AppProvider.toolbarHeightForChrome(chromeButtonSize);
    final bottomToolbarReserve =
        AppProvider.toolbarHeightForChrome(chromeButtonSize);
    final maxBodyHeight = (mediaSize.height -
            topAnchor -
            bottomToolbarReserve -
            mediaPadding.bottom -
            92)
        .clamp(140.0, 640.0)
        .toDouble();
    return _ChromePanelLayout._(panelWidth, topAnchor, maxBodyHeight);
  }

  final double panelWidth;
  final double topAnchor;
  final double maxBodyHeight;
}

TextStyle _chromePanelTitleStyle(ColorScheme scheme, double fontSize, bool isDark) {
  final uiFs = fontSize.clamp(12.0, 28.0);
  return TextStyle(
    fontSize: (uiFs * 1.25).clamp(16.0, 32.0),
    fontWeight: FontWeight.w600,
    color: isDark ? scheme.onSurface : BibleLightPalette.primaryText,
  );
}

class _SupportDialogRouteBody extends StatefulWidget {
  const _SupportDialogRouteBody();

  @override
  State<_SupportDialogRouteBody> createState() => _SupportDialogRouteBodyState();
}

class _SupportDialogRouteBodyState extends State<_SupportDialogRouteBody> {
  late final Future<_SupportDialogData> _dataFuture = _loadSupportDialogData();

  _SupportRemoteRelease? remoteRelease;
  String? remoteError;
  bool isChecking = false;
  bool hasChecked = false;
  bool remoteChangesExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (consumerContext, app, _) {
        final theme = Theme.of(consumerContext);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final layout =
            _ChromePanelLayout.fromContext(consumerContext, app.chromeButtonSize);
        final titleStyle = _chromePanelTitleStyle(scheme, app.fontSize, isDark);
        final body = theme.textTheme.bodyMedium!.copyWith(
          color: isDark ? scheme.onSurface : BibleLightPalette.secondaryText,
          fontSize: app.fontSize,
          height: app.lineHeight,
        );
        final bodyEmphasis = body.copyWith(
          color: isDark ? scheme.onSurface : BibleLightPalette.primaryText,
          fontWeight: FontWeight.w600,
        );
        final scrollMaxH = (layout.maxBodyHeight - 88).clamp(120.0, 600.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: layout.topAnchor,
              right: 0,
              child: SizedBox(
                width: layout.panelWidth,
                child: _chromePanelShell(
                  isDark: isDark,
                  lightSurface: ChromePanelLightSurface.modalOpaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: FutureBuilder<_SupportDialogData>(
                      future: _dataFuture,
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Техподдержка', style: titleStyle),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: isDark
                                        ? null
                                        : BibleLightPalette.primary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        final data = snapshot.data;
                        final currentVersion = data?.packageInfo.version ??
                            _versionNameFromPackageVersion('0.0.0+0');
                        final currentBuild = data?.packageInfo.buildNumber ??
                            _versionCodeFromPackageVersion('0.0.0+0')
                                .toString();
                        final currentCode = int.tryParse(currentBuild) ??
                            _versionCodeFromPackageVersion(
                              '$currentVersion+$currentBuild',
                            );

                        const supportPayload = 'februaryidea7@gmail.com';

                        final hasRemote = remoteRelease != null;
                        final hasUpdate =
                            hasRemote && remoteRelease!.versionCode > currentCode;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Техподдержка', style: titleStyle),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxHeight: scrollMaxH),
                              child: SingleChildScrollView(
                                child: DefaultTextStyle(
                                  style: body,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                    child: Theme(
                                      data: theme.copyWith(
                                        dividerColor: isDark
                                            ? theme.dividerColor
                                            : BibleLightPalette.cardDivider,
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        iconTheme: IconThemeData(
                                          color: isDark
                                              ? scheme.onSurface
                                              : BibleLightPalette.iconActive,
                                        ),
                                        expansionTileTheme:
                                            ExpansionTileThemeData(
                                          backgroundColor: Colors.transparent,
                                          collapsedBackgroundColor:
                                              Colors.transparent,
                                          iconColor: isDark
                                              ? scheme.onSurface
                                              : BibleLightPalette.iconActive,
                                          collapsedIconColor: isDark
                                              ? scheme.onSurface
                                              : BibleLightPalette.iconActive,
                                          textColor: isDark
                                              ? scheme.onSurface
                                              : BibleLightPalette.secondaryText,
                                          collapsedTextColor: isDark
                                              ? scheme.onSurface
                                              : BibleLightPalette.secondaryText,
                                        ),
                                        listTileTheme: ListTileThemeData(
                                          tileColor: Colors.transparent,
                                          selectedTileColor:
                                              BibleLightPalette.activeBg,
                                        ),
                                      ),
                                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Описание проекта:'),
                          const SizedBox(height: 4),
                          Text(
                            'Текст Синодального перевода Библии с элементами Септуагинты (в [...])',
                            style: bodyEmphasis,
                          ),
                          const SizedBox(height: 12),
                          const Text('Автор проекта:'),
                          const SizedBox(height: 4),
                          Text(
                            'Софеин Павел Геннадьевич',
                            style: bodyEmphasis,
                          ),
                          const SizedBox(height: 12),
                          const Text('Контактная почта:'),
                          const SizedBox(height: 4),
                          Text(
                            'februaryidea7@gmail.com',
                            style: bodyEmphasis,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Версия приложения: $currentVersion+$currentBuild',
                            style: bodyEmphasis.copyWith(
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          if (data != null && data.changelog.isNotEmpty)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.transparent,
                              collapsedBackgroundColor: Colors.transparent,
                              childrenPadding:
                                  const EdgeInsets.only(left: 4, right: 4),
                              title: Text(
                                'История версий',
                                style: body,
                              ),
                              subtitle: Text(
                                'Нажмите, чтобы посмотреть изменения',
                                style: body,
                              ),
                              children: [
                                for (final v in data.changelog)
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.transparent,
                                    collapsedBackgroundColor:
                                        Colors.transparent,
                                    childrenPadding: const EdgeInsets.only(
                                        left: 6, bottom: 2),
                                    title: Text(
                                      v.fullVersion,
                                      style: body,
                                    ),
                                    subtitle: Text(
                                      v.date,
                                      style: body,
                                    ),
                                    children: [
                                      for (final ch in v.changes)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '• $ch',
                                            style: body,
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            )
                          else ...[
                            Text(
                              'История версий',
                              style: body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Пока нет записей',
                              style: body,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Обновление',
                            style: bodyEmphasis.copyWith(
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          _supportChromeActionButton(
                            context: consumerContext,
                            icon: Icons.sync,
                            label: isChecking
                                ? 'Проверяем...'
                                : 'Проверить обновление',
                            onTap: isChecking
                                ? null
                                : () async {
                                    setState(() {
                                      isChecking = true;
                                      remoteError = null;
                                    });
                                    try {
                                      final remote =
                                          await _fetchSupportRemoteRelease();
                                      setState(() {
                                        remoteRelease = remote;
                                        hasChecked = true;
                                        isChecking = false;
                                        remoteChangesExpanded = false;
                                      });
                                    } catch (e) {
                                      setState(() {
                                        remoteRelease = null;
                                        remoteError =
                                            _friendlySupportUpdateError(e);
                                        hasChecked = true;
                                        isChecking = false;
                                        remoteChangesExpanded = false;
                                      });
                                    }
                                  },
                          ),
                          const SizedBox(height: 8),
                          if (!hasChecked)
                            Text(
                              'Нажмите кнопку для проверки обновления.',
                              style: body,
                            )
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
                            _supportChromeActionButton(
                              context: consumerContext,
                              icon: Icons.system_update_alt,
                              label: 'Скачать обновление',
                              onTap: () => unawaited(
                                _openApkDownloadUrl(
                                  consumerContext,
                                  remoteRelease!.apkUrl,
                                ),
                              ),
                            ),
                            if (remoteRelease!.changes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Theme(
                                data: Theme.of(consumerContext).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  key: ValueKey(
                                    'remote_changes_${remoteRelease!.versionCode}',
                                  ),
                                  backgroundColor: Colors.transparent,
                                  collapsedBackgroundColor: Colors.transparent,
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  childrenPadding: const EdgeInsets.only(
                                    left: 20,
                                    right: 2,
                                    bottom: 2,
                                  ),
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  maintainState: true,
                                  initiallyExpanded: remoteChangesExpanded,
                                  onExpansionChanged: (expanded) {
                                    setState(
                                      () => remoteChangesExpanded = expanded,
                                    );
                                  },
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Описание обновления',
                                        style: body,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Нажмите, чтобы посмотреть список изменений',
                                        style: body.copyWith(
                                          color: isDark
                                              ? scheme.onSurface
                                                  .withValues(alpha: 0.72)
                                              : BibleLightPalette.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    for (final ch in remoteRelease!.changes)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          '• $ch',
                                          style: body,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ] else
                            Text(
                              'Установлена актуальная версия',
                              style: body,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: NotebookChromeDialogToolbarIconButton(
                                  icon: Icons.copy_all,
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: supportPayload),
                                    );
                                    if (!consumerContext.mounted) return;
                                    ScaffoldMessenger.of(consumerContext)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Данные техподдержки скопированы',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

void showAppSupportDialog(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return const _SupportDialogRouteBody();
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

/// Заголовки разделов в окне «Инструкция» (оглавление).
const TextStyle _helpDialogTocStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontStyle: FontStyle.italic,
);

void showAppHelpDialog(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Consumer<AppProvider>(
        builder: (consumerContext, app, _) {
          final theme = Theme.of(consumerContext);
          final scheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          final fs = app.fontSize;
          final lh = app.lineHeight;
          final layout = _ChromePanelLayout.fromContext(
            consumerContext,
            app.chromeButtonSize,
          );
          final titleStyle =
              _chromePanelTitleStyle(scheme, app.fontSize, isDark);
          final tocStyle = _helpDialogTocStyle.copyWith(
            color: isDark ? scheme.onSurface : BibleLightPalette.primaryText,
            fontSize: (fs * 0.95).clamp(12.0, 26.0),
            height: lh,
          );
          final bodyStyle = theme.textTheme.bodyMedium!.copyWith(
            color: isDark ? scheme.onSurface : BibleLightPalette.secondaryText,
            fontSize: fs,
            height: lh,
          );
          final n = kParallelReadingPlan365.length;
          final scrollMaxH =
              (layout.maxBodyHeight - 48).clamp(120.0, 600.0).toDouble();

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: layout.topAnchor,
                right: 0,
                child: SizedBox(
                  width: layout.panelWidth,
                  child: _chromePanelShell(
                    isDark: isDark,
                    lightSurface: ChromePanelLightSurface.modalOpaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Инструкция', style: titleStyle),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints:
                                BoxConstraints(maxHeight: scrollMaxH),
                            child: SingleChildScrollView(
                              child: DefaultTextStyle(
                                style: bodyStyle,
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
                      '• Окна выбора книги, главы, поиска и избранного закрываются '
                      'системной кнопкой «Назад» или тапом по затемнённой области вокруг окна.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Поиск',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Введите одно слово или несколько — поиск выполняется автоматически по мере набора.',
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
                      '(настройки, инструкция, выход и другое).',
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
                      '• После копирования и вставки текст в буфере сохраняется, '
                      'поэтому его можно вставлять повторно при необходимости.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'План чтения:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Для годовых планов сначала показаны четыре квартала; для тематических («Вера», «Надежда», «Любовь») — по одному кварталу; '
                      'для плана «Для начинающих» — тоже четыре квартала, но с поэтапным маршрутом для новичка. '
                      'Число дней в маршруте: «Вера» и «Надежда» — $kFaithPlanDayCount, «Любовь» — $kLovePlanDayCount. '
                      'Внутри квартала — дни подряд (для годовых планов номера 1…$n по году; для тематических — дни по номерам этого маршрута). '
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
                    const SizedBox(height: 12),
                    Text(
                      'Тематические планы («Вера», «Надежда», «Любовь»)',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'У каждого тематического плана — маршрут из нескольких дней ($kFaithPlanDayCount или $kLovePlanDayCount) с темой и пояснениями к отрывкам: '
                      'на экране выбора один квартал и блок советов по чтению. В списке дней слева — ссылки на стихи, '
                      'справа — краткая мысль. Отметки «прочитано» для каждого тематического плана хранятся раздельно и отдельно от остальных планов.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'План «Для начинающих»',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Этот план разбит на четыре последовательных квартала для плавного входа в чтение: '
                      '1-й квартал — Евангелие от Иоанна, 2-й — Деяния, 3-й — Римлянам, 4-й — Галатам. '
                      'Внутри каждого квартала дни идут по порядку, с отдельным прогрессом по дням и кварталам. '
                      'Отметки «прочитано» в плане «Для начинающих» хранятся отдельно от всех остальных планов.',
                    ),
                  ],
                                ),
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
