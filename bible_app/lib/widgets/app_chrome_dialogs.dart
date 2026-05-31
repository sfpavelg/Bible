import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:bible_app/journal/faith_reading_plan_data.dart';
import 'package:bible_app/journal/love_reading_plan_data.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/chrome_frost_glass_panel.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/chrome_pill_two_segment_control.dart';
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

  /// Настройки: Frosted Glass Minimal (blur + стеклянные карточки).
  settingsFrostGlass,

  /// Как [settingsFrostGlass], но без BackdropFilter — для длинной прокрутки.
  settingsFrostGlassStatic,

  /// Устаревший непрозрачный вариант (оставлен для совместимости switch).
  modalOpaque,
}

/// Корпус боковых панелей «Настройки», «Техподдержка», «Инструкция».
/// Радиус внешней оболочки боковых панелей ([_chromePanelShell]).
const double _kChromePanelShellRadius = 12;

Widget _chromePanelShell({
  required bool isDark,
  double borderRadius = _kChromePanelShellRadius,
  ChromePanelLightSurface lightSurface = ChromePanelLightSurface.chromeCardGlass,
  required Widget child,
}) {
  if (isDark) {
    return Material(
      color: BibleDarkPalette.cardBg,
      elevation: 12,
      shadowColor: const Color(0x80000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: BibleDarkPalette.cardBorderGold, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
  if (lightSurface == ChromePanelLightSurface.modalOpaque) {
    return Material(
      color: BibleLightPalette.modalPanelSolid,
      elevation: 8,
      shadowColor: const Color(0x287B6DFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BibleLightPalette.chromePillOutlineSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
  final BoxDecoration decoration = switch (lightSurface) {
    ChromePanelLightSurface.settingsPanel =>
      BibleLightPalette.lightSettingsPanelDecoration(radius: borderRadius),
    ChromePanelLightSurface.settingsFrostGlass ||
    ChromePanelLightSurface.settingsFrostGlassStatic =>
      const BoxDecoration(color: Colors.transparent),
    ChromePanelLightSurface.modalOpaque =>
      const BoxDecoration(color: Colors.transparent),
    ChromePanelLightSurface.chromeCardGlass =>
      BibleLightPalette.lightPanelShellDecoration(radius: borderRadius),
  };
  if (lightSurface == ChromePanelLightSurface.settingsFrostGlass ||
      lightSurface == ChromePanelLightSurface.settingsFrostGlassStatic) {
    return chromeFrostGlassPanelShell(
      borderRadius: borderRadius,
      backdropBlur:
          lightSurface == ChromePanelLightSurface.settingsFrostGlass,
      child: child,
    );
  }
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
  final glass = !isDark;
  final iconSize = (chrome * 0.48).clamp(18.0, 30.0);
  final fontSize = (chrome * 0.32).clamp(12.0, 17.0);
  final fg = isDark
      ? BibleDarkPalette.primaryText
      : (glass
          ? BibleLightPalette.settingsGlassTextPrimary
          : BibleLightPalette.primaryText);
  final ic = isDark
      ? BibleDarkPalette.iconActive
      : (glass
          ? BibleLightPalette.settingsGlassPrimary
          : BibleLightPalette.iconActive);
  return Material(
    color: isDark ? BibleDarkPalette.cardBg.withValues(alpha: 0.92) : (glass
        ? BibleLightPalette.settingsGlassCard
        : BibleLightPalette.activeBg),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(glass ? 12 : 8),
      side: isDark
          ? BorderSide(color: BibleDarkPalette.cardBorderGold, width: 1)
          : (glass
              ? BorderSide(
                  color: BibleLightPalette.settingsGlassBorderActive,
                  width: 1.2,
                )
              : BibleLightPalette.chromePillOutlineSide),
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

Widget _chromeSidePanelSectionCard({
  required bool isDark,
  required List<Widget> children,
}) {
  const radius = 14.0;
  final outline = isDark
      ? BorderSide(color: BibleDarkPalette.cardBorderGold, width: 1)
      : BibleLightPalette.chromePillOutlineSide;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: isDark
          ? BibleDarkPalette.modalSectionCardBg
          : BibleLightPalette.modalSectionCard,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: outline,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

Widget _chromeSupportSectionCard({
  required bool isDark,
  required String? sectionTitle,
  required TextStyle sectionStyle,
  required List<Widget> children,
}) {
  return _chromeSidePanelSectionCard(
    isDark: isDark,
    children: [
      if (sectionTitle != null) ...[
        Text(sectionTitle, style: sectionStyle),
        const SizedBox(height: 6),
      ],
      ...children,
    ],
  );
}

TextStyle _settingsGlassTextStyle(TextStyle base) => base.copyWith(
      decoration: TextDecoration.none,
      decorationColor: null,
      backgroundColor: null,
      shadows: BibleLightPalette.settingsGlassTextShadows,
    );

double _settingsSliderOneCharWidth(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'А', style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Ползунок настроек: единая разметка (подпись → отступ → дорожка), padding только в теме.
class _SettingsSliderRow extends StatelessWidget {
  const _SettingsSliderRow({
    required this.label,
    required this.labelStyle,
    required this.theme,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.gapAfter = 5,
    this.insetH = 12,
    this.thumbRadius = 7,
  });

  final String label;
  final TextStyle labelStyle;
  final SliderThemeData theme;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final double gapAfter;

  /// Горизонтальный отступ дорожки — как у [_SettingsFontPresetPicker].
  final double insetH;
  final double thumbRadius;

  @override
  Widget build(BuildContext context) {
    // Дорожка справа на insetH; слева — ближе к подписи и кнопкам (≈2 символа).
    final charTrim = _settingsSliderOneCharWidth(labelStyle);
    final trackInsetH = (insetH - thumbRadius).clamp(0.0, double.infinity);
    final leftTrackPad =
        (trackInsetH - charTrim * 2).clamp(0.0, double.infinity);
    final edgePad = EdgeInsets.only(left: leftTrackPad, right: trackInsetH);
    final thumbPad = EdgeInsets.symmetric(horizontal: thumbRadius);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        ClipRect(
          child: Padding(
            padding: edgePad,
            child: SliderTheme(
              data: theme,
              child: Slider(
                padding: thumbPad,
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                label: valueLabel,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        SizedBox(height: gapAfter),
      ],
    );
  }
}

SliderThemeData _settingsSliderTheme({
  required bool isDark,
  required double thumbRadius,
}) {
  if (isDark) {
    return SliderThemeData(
      trackHeight: 4,
      padding: EdgeInsets.zero,
      trackShape: const RoundedRectSliderTrackShape(),
      activeTrackColor: BibleDarkPalette.accentGold,
      inactiveTrackColor: BibleDarkPalette.divider,
      thumbColor: BibleDarkPalette.accentGold,
      overlayColor: BibleDarkPalette.accentGoldLight.withValues(alpha: 0.18),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
      overlayShape: RoundSliderOverlayShape(overlayRadius: thumbRadius + 6),
      tickMarkShape: const _SettingsSliderVerticalTickMarkShape(),
      activeTickMarkColor: BibleDarkPalette.accentGold,
      inactiveTickMarkColor: BibleDarkPalette.iconInactive,
      disabledActiveTickMarkColor: Colors.grey.shade600,
      disabledInactiveTickMarkColor: Colors.grey.shade500,
    );
  }
  return SliderThemeData(
    trackHeight: 2.5,
    padding: EdgeInsets.zero,
    trackShape: const RoundedRectSliderTrackShape(),
    activeTrackColor: BibleLightPalette.settingsGlassPrimary,
    inactiveTrackColor:
        BibleLightPalette.settingsGlassTextDisabled.withValues(alpha: 0.35),
    thumbColor: BibleLightPalette.settingsGlassPrimary,
    overlayColor:
        BibleLightPalette.settingsGlassActiveGlow.withValues(alpha: 0.28),
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
    overlayShape: RoundSliderOverlayShape(overlayRadius: thumbRadius + 6),
    tickMarkShape: const _SettingsSliderVerticalTickMarkShape(),
    activeTickMarkColor: BibleLightPalette.settingsGlassHover,
    inactiveTickMarkColor: BibleLightPalette.settingsGlassTextSecondary,
    disabledActiveTickMarkColor: Colors.grey.shade600,
    disabledInactiveTickMarkColor: Colors.grey.shade500,
  );
}

/// Выбор шрифта: строка-триггер и раскрывающаяся панель вариантов снизу.
class _SettingsFontPresetPicker extends StatelessWidget {
  const _SettingsFontPresetPicker({
    required this.value,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelected,
    required this.rowHeight,
    required this.fieldPadH,
    required this.isDark,
    required this.glass,
    required this.labelStyle,
    required this.scheme,
  });

  final String value;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSelected;
  final double rowHeight;
  final double fieldPadH;
  final bool isDark;
  final bool glass;
  final TextStyle labelStyle;
  final ColorScheme scheme;

  BoxDecoration _fieldDecoration({double radius = 12}) {
    final borderColor = isDark
        ? BibleDarkPalette.cardBorderGold
        : (glass
            ? BibleLightPalette.settingsGlassBorderActive
            : BibleLightPalette.chromePillOutlineColor);
    final fill = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.75)
        : (glass
            ? BibleLightPalette.settingsGlassCard
            : BibleLightPalette.activeBg);
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLabel =
        AppProvider.verseFontLabels[value] ?? AppProvider.verseFontLabels['sans']!;
    final chevronColor = isDark
        ? BibleDarkPalette.titleGold
        : BibleLightPalette.settingsGlassTextSecondary;
    final triggerTextStyle = isDark
        ? labelStyle.copyWith(color: BibleDarkPalette.titleGold)
        : labelStyle;
    final panelRadius = glass ? 12.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(panelRadius),
            child: Container(
              height: rowHeight,
              padding: EdgeInsets.symmetric(horizontal: fieldPadH),
              decoration: _fieldDecoration(radius: panelRadius),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentLabel,
                      style: triggerTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: chevronColor,
                      size: (labelStyle.fontSize ?? 14) * 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              decoration: _fieldDecoration(radius: panelRadius),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in AppProvider.verseFontLabels.entries) ...[
                    if (entry.key != AppProvider.verseFontLabels.keys.first)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? scheme.outlineVariant.withValues(alpha: 0.35)
                            : BibleLightPalette.settingsGlassBorderActive
                                .withValues(alpha: 0.45),
                      ),
                    _FontPresetOptionTile(
                      label: entry.value,
                      selected: entry.key == value,
                      rowHeight: rowHeight,
                      fieldPadH: fieldPadH,
                      isDark: isDark,
                      glass: glass,
                      labelStyle: labelStyle,
                      scheme: scheme,
                      onTap: () => onSelected(entry.key),
                    ),
                  ],
                ],
              ),
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 160),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

class _FontPresetOptionTile extends StatelessWidget {
  const _FontPresetOptionTile({
    required this.label,
    required this.selected,
    required this.rowHeight,
    required this.fieldPadH,
    required this.isDark,
    required this.glass,
    required this.labelStyle,
    required this.scheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double rowHeight;
  final double fieldPadH;
  final bool isDark;
  final bool glass;
  final TextStyle labelStyle;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDark
        ? scheme.primary.withValues(alpha: 0.28)
        : (glass
            ? BibleLightPalette.settingsGlassPrimary
            : BibleLightPalette.primary);
    final selectedFg = isDark ? scheme.onPrimary : Colors.white;
    final idleFg = labelStyle.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: rowHeight,
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: fieldPadH),
          color: selected ? selectedBg : Colors.transparent,
          child: Text(
            label,
            style: labelStyle.copyWith(
              color: selected ? selectedFg : idleFg,
              fontWeight: selected ? FontWeight.w600 : labelStyle.fontWeight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

Widget _settingsToggleRow({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
  required TextStyle labelStyle,
  required SwitchThemeData switchTheme,
  bool glass = false,
}) {
  final row = SwitchTheme(
    data: switchTheme,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        Switch(
          value: value,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: onChanged,
        ),
      ],
    ),
  );
  if (!glass) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: row,
    );
  }
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BibleLightPalette.settingsGlassCardDecoration(radius: 20),
    child: row,
  );
}

void showAppSettingsDialog(BuildContext context) {
  final appProvider = Provider.of<AppProvider>(context, listen: false);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Прозрачный barrier: затемнение в Stack, чтобы BackdropFilter размывал текст Библии.
    barrierColor: Colors.transparent,
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
      bool fontPresetPickerOpen = false;
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
              final glass = !isDark;
              final textPrimary = isDark
                  ? BibleDarkPalette.primaryText
                  : (glass
                      ? BibleLightPalette.settingsGlassTextPrimary
                      : BibleLightPalette.primaryText);
              final textHeading = isDark
                  ? BibleDarkPalette.titleGold
                  : (glass
                      ? BibleLightPalette.settingsGlassTextPrimary
                      : BibleLightPalette.primaryDark);
              TextStyle settingsLabelStyle({
                required double size,
                required FontWeight weight,
                required Color color,
              }) {
                final base = TextStyle(
                  fontSize: size,
                  fontWeight: weight,
                  color: color,
                  height: 1.2,
                );
                return glass ? _settingsGlassTextStyle(base) : base;
              }

              final kSettingsTitleStyle = settingsLabelStyle(
                size: (uiFs * 1.25).clamp(16.0, 32.0),
                weight: FontWeight.w700,
                color: textHeading,
              );
              final kSettingsHeadingStyle = settingsLabelStyle(
                size: (uiFs * 0.9).clamp(12.0, 26.0),
                weight: FontWeight.w600,
                color: textHeading,
              );
              final kSettingsBodyStyle = settingsLabelStyle(
                size: uiFs,
                weight: FontWeight.w500,
                color: textPrimary,
              );
              final kSettingsDarkToggleRowStyle = settingsLabelStyle(
                size: uiFs,
                weight: FontWeight.w500,
                color: BibleDarkPalette.titleGold,
              );
              final settingsFieldPadH = (uiFs * 0.5).clamp(10.0, 14.0);
              final settingsControlRowH = (uiFs * 1.75).clamp(36.0, 48.0);
              final themeSegmentFs = (uiFs * 0.92).clamp(12.0, 24.0);
              final settingsSwitchTheme = SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return isDark
                        ? const Color(0xFF1A1A1A)
                        : Colors.white;
                  }
                  return isDark
                      ? BibleDarkPalette.iconInactive
                      : BibleLightPalette.settingsGlassPrimary;
                }),
                trackColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return isDark
                        ? BibleDarkPalette.accentGold
                        : BibleLightPalette.settingsGlassPrimary;
                  }
                  return isDark
                      ? BibleDarkPalette.cardBg
                      : BibleLightPalette.settingsGlassTextDisabled
                          .withValues(alpha: 0.45);
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return Colors.transparent;
                  }
                  return isDark
                      ? BibleDarkPalette.cardBorderGold.withValues(alpha: 0.55)
                      : BibleLightPalette.settingsGlassBorderActive
                          .withValues(alpha: 0.65);
                }),
                trackOutlineWidth: const WidgetStatePropertyAll(1.2),
              );
              final settingsSliderThumbRadius = isDark ? 10.0 : 7.0;

              final settingsSliderThemeData = _settingsSliderTheme(
                isDark: isDark,
                thumbRadius: settingsSliderThumbRadius,
              );

              final panelPadH = isDark ? 12.0 : 10.0;
              final mediaSize = MediaQuery.sizeOf(consumerContext);
              final mediaPadding = MediaQuery.paddingOf(consumerContext);
              final panelWidth =
                  ((mediaSize.width - 12) * (2 / 3)).clamp(300.0, 362.5);
              final topAnchor = mediaPadding.top +
                  AppProvider.toolbarHeightForChrome(chromeBtnSize);
              final bottomToolbarReserve =
                  AppProvider.toolbarHeightForChrome(chromeBtnSize);
              final panelMaxHeight = (mediaSize.height -
                      topAnchor -
                      bottomToolbarReserve -
                      mediaPadding.bottom -
                      8)
                  .clamp(160.0, 2000.0)
                  .toDouble();

              final readingBlocks = <Widget>[
                                      _SettingsSliderRow(
                                        label: 'Размер шрифта',
                                        labelStyle: kSettingsHeadingStyle,
                                        theme: settingsSliderThemeData,
                                        insetH: settingsFieldPadH,
                                        thumbRadius: settingsSliderThumbRadius,
                                        value: fontSize,
                                        min: 12,
                                        max: 28,
                                        divisions: 16,
                                        valueLabel:
                                            fontSize.toStringAsFixed(0),
                                        onChanged: (value) {
                                          setModalState(() => fontSize = value);
                                          appProvider.changeFontSize(value);
                                        },
                                      ),
                                      _SettingsSliderRow(
                                        label: 'Межстрочный интервал',
                                        labelStyle: kSettingsHeadingStyle,
                                        theme: settingsSliderThemeData,
                                        insetH: settingsFieldPadH,
                                        thumbRadius: settingsSliderThumbRadius,
                                        value: lineHeight,
                                        min: 1,
                                        max: 2.2,
                                        divisions: 12,
                                        valueLabel:
                                            lineHeight.toStringAsFixed(2),
                                        onChanged: (value) {
                                          setModalState(
                                              () => lineHeight = value);
                                          appProvider.changeLineHeight(value);
                                        },
                                      ),
                                      _SettingsSliderRow(
                                        label: 'Интервал между стихами',
                                        labelStyle: kSettingsHeadingStyle,
                                        theme: settingsSliderThemeData,
                                        insetH: settingsFieldPadH,
                                        thumbRadius: settingsSliderThumbRadius,
                                        value: verseSpacing,
                                        min: 0,
                                        max: 28,
                                        divisions: 28,
                                        valueLabel:
                                            verseSpacing.toStringAsFixed(0),
                                        gapAfter: 8,
                                        onChanged: (value) {
                                          setModalState(
                                              () => verseSpacing = value);
                                          appProvider.changeVerseSpacing(value);
                                        },
                                      ),
                                      Text(
                                        'Шрифт текста',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      _SettingsFontPresetPicker(
                                        value: fontPreset,
                                        expanded: fontPresetPickerOpen,
                                        rowHeight: settingsControlRowH,
                                        fieldPadH: settingsFieldPadH,
                                        isDark: isDark,
                                        glass: glass,
                                        labelStyle: kSettingsBodyStyle,
                                        scheme: scheme,
                                        onToggleExpanded: () {
                                          setModalState(() {
                                            fontPresetPickerOpen =
                                                !fontPresetPickerOpen;
                                          });
                                        },
                                        onSelected: (preset) {
                                          setModalState(() {
                                            fontPreset = preset;
                                            fontPresetPickerOpen = false;
                                          });
                                          appProvider.setVerseFontPreset(preset);
                                        },
                                      ),
                                      const SizedBox(height: 6),
              ];

              final uiBlocks = <Widget>[
                                      _SettingsSliderRow(
                                        label: 'Размер кнопок',
                                        labelStyle: kSettingsHeadingStyle,
                                        theme: settingsSliderThemeData,
                                        insetH: settingsFieldPadH,
                                        thumbRadius: settingsSliderThumbRadius,
                                        value: chromeBtnSize,
                                        min: AppProvider.chromeButtonSizeMin,
                                        max: AppProvider.chromeButtonSizeMax,
                                        divisions: 24,
                                        valueLabel:
                                            chromeBtnSize.round().toString(),
                                        gapAfter: 8,
                                        onChanged: (value) {
                                          setModalState(
                                              () => chromeBtnSize = value);
                                          appProvider
                                              .changeChromeButtonSize(value);
                                        },
                                      ),
                                      Text(
                                        'Тема',
                                        style: kSettingsHeadingStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      ChromePillTwoSegmentControl<ThemeMode>(
                                        value: selectedTheme,
                                        leftValue: ThemeMode.light,
                                        rightValue: ThemeMode.dark,
                                        leftLabel: 'Светлая',
                                        rightLabel: 'Тёмная',
                                        rowHeight: settingsControlRowH,
                                        fontSize: themeSegmentFs,
                                        isDark: isDark,
                                        trackColor: glass
                                            ? BibleLightPalette.disabledBg
                                            : (isDark
                                                ? BibleDarkPalette.cardBg
                                                : null),
                                        activeColor: glass
                                            ? BibleLightPalette
                                                .settingsGlassPrimary
                                            : (isDark
                                                ? BibleDarkPalette.accentGold
                                                : null),
                                        activeForegroundColor: glass
                                            ? null
                                            : (isDark
                                                ? Colors.black
                                                : null),
                                        inactiveForegroundColor: glass
                                            ? BibleLightPalette
                                                .settingsGlassTextSecondary
                                            : (isDark
                                                ? BibleDarkPalette.accentGold
                                                : null),
                                        borderColor: glass
                                            ? BibleLightPalette
                                                .chromePillOutlineColor
                                            : (isDark
                                                ? BibleDarkPalette.cardBorderGold
                                                : null),
                                        labelShadows: glass
                                            ? BibleLightPalette
                                                .settingsGlassTextShadows
                                            : null,
                                        onChanged: (m) {
                                          setModalState(() => selectedTheme = m);
                                          appProvider.setThemeMode(m);
                                        },
                                      ),
              ];

              final settingsFields = <Widget>[
                      ...readingBlocks,
                      ...uiBlocks,
                      _settingsToggleRow(
                        label: 'Септуагинта [ ]',
                        value: showSeptuagintText,
                        labelStyle: glass
                            ? kSettingsHeadingStyle
                            : kSettingsDarkToggleRowStyle,
                        switchTheme: settingsSwitchTheme,
                        glass: false,
                        onChanged: (value) {
                          setModalState(() => showSeptuagintText = value);
                          appProvider.setShowSeptuagintText(value);
                        },
                      ),
                      _settingsToggleRow(
                        label: 'Не выключать экран',
                        value: keepScreenOn,
                        labelStyle: glass
                            ? kSettingsHeadingStyle
                            : kSettingsDarkToggleRowStyle,
                        switchTheme: settingsSwitchTheme,
                        glass: false,
                        onChanged: (value) async {
                          setModalState(() => keepScreenOn = value);
                          await appProvider.setKeepScreenOn(value);
                        },
                      ),
                    ];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: ColoredBox(
                        color: isDark
                            ? const Color(0x8A000000)
                            : const Color(0x24000000),
                      ),
                    ),
                  ),
                  Positioned(
                    top: topAnchor,
                    right: 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: panelWidth,
                        maxHeight: panelMaxHeight,
                      ),
                      child: _chromePanelShell(
                        isDark: isDark,
                        lightSurface: ChromePanelLightSurface.settingsFrostGlass,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            panelPadH,
                            10,
                            panelPadH,
                            glass ? 12 : 10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Настройки',
                                style: kSettingsTitleStyle,
                              ),
                              const SizedBox(height: 6),
                              Flexible(
                                fit: FlexFit.loose,
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: settingsFields,
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
  _ChromePanelLayout._(this.panelWidth, this.topAnchor, this.panelMaxHeight);

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
    final panelMaxHeight = (mediaSize.height -
            topAnchor -
            bottomToolbarReserve -
            mediaPadding.bottom -
            8)
        .clamp(160.0, 2000.0)
        .toDouble();
    return _ChromePanelLayout._(panelWidth, topAnchor, panelMaxHeight);
  }

  final double panelWidth;
  final double topAnchor;
  final double panelMaxHeight;
}

/// Стили текста боковых панелей (настройки, техподдержка, инструкция).
class _ChromeSidePanelTextTheme {
  const _ChromeSidePanelTextTheme({
    required this.isDark,
    required this.glass,
    required this.titleStyle,
    required this.bodyStyle,
    required this.bodyEmphasisStyle,
    required this.sectionStyle,
    required this.tocStyle,
  });

  final bool isDark;
  final bool glass;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle bodyEmphasisStyle;
  final TextStyle sectionStyle;
  final TextStyle tocStyle;

  factory _ChromeSidePanelTextTheme.create({
    required double fontSize,
    required double lineHeight,
    required bool isDark,
    bool? glassTypography,
  }) {
    final glass = glassTypography ?? !isDark;
    final uiFs = fontSize.clamp(12.0, 28.0);
    final primary = isDark
        ? BibleDarkPalette.primaryText
        : (glass
            ? BibleLightPalette.settingsGlassTextPrimary
            : BibleLightPalette.primaryText);
    final heading = isDark
        ? BibleDarkPalette.titleGold
        : primary;
    final secondary = isDark
        ? BibleDarkPalette.secondaryText
        : (glass
            ? BibleLightPalette.settingsGlassTextSecondary
            : BibleLightPalette.secondaryText);

    TextStyle label({
      required double size,
      required FontWeight weight,
      required Color color,
      FontStyle fontStyle = FontStyle.normal,
    }) {
      final base = TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: lineHeight,
        fontStyle: fontStyle,
      );
      return glass ? _settingsGlassTextStyle(base) : base;
    }

    return _ChromeSidePanelTextTheme(
      isDark: isDark,
      glass: glass,
      titleStyle: label(
        size: (uiFs * 1.25).clamp(16.0, 32.0),
        weight: FontWeight.w700,
        color: heading,
      ),
      bodyStyle: label(
        size: uiFs,
        weight: FontWeight.w500,
        color: primary,
      ),
      bodyEmphasisStyle: label(
        size: uiFs,
        weight: FontWeight.w600,
        color: primary,
      ),
      sectionStyle: label(
        size: (uiFs * 0.92).clamp(12.0, 22.0),
        weight: FontWeight.w700,
        color: isDark ? BibleDarkPalette.titleGold : secondary,
      ),
      tocStyle: label(
        size: (uiFs * 0.95).clamp(12.0, 26.0),
        weight: FontWeight.w700,
        color: heading,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

Widget _chromeSidePanelDismissBarrier(
  BuildContext dialogContext,
  bool isDark,
) {
  return Positioned.fill(
    child: GestureDetector(
      onTap: () => Navigator.of(dialogContext).pop(),
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: isDark ? const Color(0x8A000000) : const Color(0x24000000),
      ),
    ),
  );
}

  /// Боковая панель: затемнение, frost-glass, фиксированный заголовок, прокрутка.
Widget _chromeSidePanelScaffold({
  required BuildContext dialogContext,
  required bool isDark,
  required _ChromePanelLayout layout,
  required String title,
  required TextStyle titleStyle,
  Widget? scrollChild,
  List<Widget>? scrollSlivers,
  ScrollController? scrollController,
  List<Widget> pinnedBelowTitle = const [],
  bool embedScrollChild = false,
  List<Widget> footer = const [],
  ChromePanelLightSurface lightSurface =
      ChromePanelLightSurface.settingsFrostGlass,
}) {
  assert(
    scrollChild != null || scrollSlivers != null,
    'scrollChild or scrollSlivers required',
  );
  final glass = !isDark &&
      (lightSurface == ChromePanelLightSurface.settingsFrostGlass ||
          lightSurface == ChromePanelLightSurface.settingsFrostGlassStatic);
  return Stack(
    clipBehavior: Clip.none,
    children: [
      _chromeSidePanelDismissBarrier(dialogContext, isDark),
      Positioned(
        top: layout.topAnchor,
        right: 0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: layout.panelWidth,
            maxHeight: layout.panelMaxHeight,
          ),
          child: _chromePanelShell(
            isDark: isDark,
            lightSurface: lightSurface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 10, 10, glass ? 12 : 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 6),
                  ...pinnedBelowTitle,
                  Flexible(
                    fit: FlexFit.loose,
                    child: scrollSlivers != null
                        ? CustomScrollView(
                            controller: scrollController,
                            physics: const ClampingScrollPhysics(),
                            slivers: scrollSlivers,
                          )
                        : embedScrollChild
                            ? RepaintBoundary(child: scrollChild!)
                            : SingleChildScrollView(
                                controller: scrollController,
                                physics: const ClampingScrollPhysics(),
                                clipBehavior: Clip.none,
                                child: RepaintBoundary(child: scrollChild!),
                              ),
                  ),
                  ...footer,
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

const double _kChromeSidePanelSectionRadius = 14;

Color _chromeSidePanelSectionFill(bool isDark) => isDark
    ? BibleDarkPalette.modalSectionCardBg
    : BibleLightPalette.modalSectionCard;

/// Раскрывающийся блок без ExpansionTile (избегаем серой подложки Material 3).
class _SupportCollapsibleBlock extends StatefulWidget {
  const _SupportCollapsibleBlock({
    super.key,
    required this.title,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.children,
    this.subtitle,
    this.chevronColor,
    this.chevronSize,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final String title;
  final String? subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final List<Widget> children;
  final Color? chevronColor;
  final double? chevronSize;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<_SupportCollapsibleBlock> createState() =>
      _SupportCollapsibleBlockState();
}

class _SupportCollapsibleBlockState extends State<_SupportCollapsibleBlock> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedChevronColor = widget.chevronColor ??
        widget.titleStyle.color ??
        BibleLightPalette.settingsGlassTextPrimary;
    final resolvedChevronSize =
        widget.chevronSize ?? (widget.titleStyle.fontSize ?? 14) * 1.35;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: widget.titleStyle),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(widget.subtitle!, style: widget.subtitleStyle),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: resolvedChevronColor,
                    size: resolvedChevronSize,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

class _SupportDialogRouteBody extends StatefulWidget {
  const _SupportDialogRouteBody({required this.dialogContext});

  final BuildContext dialogContext;

  @override
  State<_SupportDialogRouteBody> createState() => _SupportDialogRouteBodyState();
}

class _SupportDialogRouteBodyState extends State<_SupportDialogRouteBody> {
  late final Future<_SupportDialogData> _dataFuture = _loadSupportDialogData();
  final ScrollController _panelScrollController = ScrollController();
  final GlobalKey<ScaffoldMessengerState> _supportSnackMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  _SupportRemoteRelease? remoteRelease;
  String? remoteError;
  bool isChecking = false;
  bool hasChecked = false;
  bool remoteChangesExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.maybeOf(widget.dialogContext)?.clearSnackBars();
    });
  }

  @override
  void dispose() {
    _panelScrollController.dispose();
    super.dispose();
  }

  void _scrollPanelToBottom() {
    void scrollIfNeeded() {
      if (!mounted || !_panelScrollController.hasClients) return;
      final position = _panelScrollController.position;
      final target = position.maxScrollExtent;
      if (target <= position.pixels + 1) return;
      _panelScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    // Два кадра: после setState контент «Обновление» сначала перестраивается, затем считается высота.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollIfNeeded();
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollIfNeeded());
    });
  }

  static const String _supportEmail = 'februaryidea7@gmail.com';

  void _showSupportPanelSnackBar(String message) {
    final messenger = _supportSnackMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: BibleLightPalette.settingsGlassPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _supportEmailRow({
    required _ChromePanelLayout layout,
    required _ChromeSidePanelTextTheme text,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Контактная почта:', style: text.sectionStyle),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(_supportEmail, style: text.bodyEmphasisStyle),
              ),
              const SizedBox(width: 8),
              NotebookChromeDialogToolbarIconButton(
                icon: Icons.copy_all,
                tooltip: 'Скопировать почту',
                iconColor: isDark
                    ? null
                    : BibleLightPalette.settingsGlassPrimary,
                borderColor: isDark
                    ? null
                    : BibleLightPalette.settingsGlassBorderActive,
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _supportEmail),
                  );
                  if (!mounted) return;
                  _showSupportPanelSnackBar('Адрес почты скопирован');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _supportInfoRow({
    required String label,
    required String value,
    required _ChromeSidePanelTextTheme text,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.sectionStyle),
          const SizedBox(height: 4),
          Text(value, style: valueStyle ?? text.bodyEmphasisStyle),
        ],
      ),
    );
  }

  Widget _buildSupportScroll({
    required BuildContext consumerContext,
    required _ChromePanelLayout layout,
    required ThemeData theme,
    required ColorScheme scheme,
    required _ChromeSidePanelTextTheme text,
    required bool isDark,
    required _SupportDialogData? data,
  }) {
    final body = text.bodyStyle;
    final bodyEmphasis = text.bodyEmphasisStyle;
    final currentVersion = data?.packageInfo.version ??
        _versionNameFromPackageVersion('0.0.0+0');
    final currentBuild = data?.packageInfo.buildNumber ??
        _versionCodeFromPackageVersion('0.0.0+0').toString();
    final currentCode = int.tryParse(currentBuild) ??
        _versionCodeFromPackageVersion('$currentVersion+$currentBuild');
    final hasRemote = remoteRelease != null;
    final hasUpdate = hasRemote && remoteRelease!.versionCode > currentCode;
    final changelogVersions =
        data?.changelog ?? const <_SupportChangelogEntry>[];

    final aboutSection = _chromeSupportSectionCard(
      isDark: isDark,
      sectionTitle: 'О проекте',
      sectionStyle: text.sectionStyle,
      children: [
        _supportInfoRow(
          label: 'Описание проекта:',
          value:
              'Текст Синодального перевода Библии с элементами Септуагинты (в [...])',
          text: text,
        ),
        _supportInfoRow(
          label: 'Автор проекта:',
          value: 'Софеин Павел Геннадьевич',
          text: text,
        ),
        _supportEmailRow(
          layout: layout,
          text: text,
          isDark: isDark,
        ),
        _supportInfoRow(
          label: 'Версия приложения:',
          value: '$currentVersion+$currentBuild',
          text: text,
          valueStyle: bodyEmphasis.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );

    final changelogSection = _chromeSupportSectionCard(
      isDark: isDark,
      sectionTitle: changelogVersions.isEmpty ? 'История версий' : null,
      sectionStyle: text.sectionStyle,
      children: [
        if (changelogVersions.isNotEmpty)
          _SupportCollapsibleBlock(
            title: 'История версий',
            titleStyle: text.sectionStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
            subtitleStyle: text.sectionStyle,
            chevronColor: body.color,
            chevronSize: (body.fontSize ?? 14) * 1.35,
            initiallyExpanded: false,
            children: [
              for (var i = 0; i < changelogVersions.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _SupportCollapsibleBlock(
                  initiallyExpanded: false,
                  title: changelogVersions[i].fullVersion,
                  subtitle: changelogVersions[i].date,
                  titleStyle: body,
                  subtitleStyle: text.sectionStyle,
                  children: [
                    for (final ch in changelogVersions[i].changes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $ch', style: body),
                      ),
                  ],
                ),
              ],
            ],
          )
        else
          Text('Пока нет записей', style: body),
      ],
    );

    final updateSection = _chromeSupportSectionCard(
      isDark: isDark,
      sectionTitle: 'Обновление',
      sectionStyle: text.sectionStyle,
      children: [
        _supportChromeActionButton(
          context: consumerContext,
          icon: Icons.sync,
          label: isChecking ? 'Проверяем...' : 'Проверить обновление',
          onTap: isChecking
              ? null
              : () async {
                  setState(() {
                    isChecking = true;
                    remoteError = null;
                  });
                  try {
                    final remote = await _fetchSupportRemoteRelease();
                    setState(() {
                      remoteRelease = remote;
                      hasChecked = true;
                      isChecking = false;
                      remoteChangesExpanded = false;
                    });
                    _scrollPanelToBottom();
                  } catch (e) {
                    setState(() {
                      remoteRelease = null;
                      remoteError = _friendlySupportUpdateError(e);
                      hasChecked = true;
                      isChecking = false;
                      remoteChangesExpanded = false;
                    });
                    _scrollPanelToBottom();
                  }
                },
        ),
        if (remoteError != null) ...[
          const SizedBox(height: 8),
          Text(
            remoteError!,
            style: body.copyWith(color: Colors.orange.shade700),
          ),
        ] else if (hasRemote && hasUpdate) ...[
          const SizedBox(height: 8),
          Text(
            'Доступна новая версия: '
            '${remoteRelease!.versionName}+${remoteRelease!.versionCode}',
            style: bodyEmphasis,
          ),
          const SizedBox(height: 8),
          _supportChromeActionButton(
            context: consumerContext,
            icon: Icons.system_update_alt,
            label: 'Скачать обновление',
            onTap: () => unawaited(
              _openApkDownloadUrl(consumerContext, remoteRelease!.apkUrl),
            ),
          ),
          if (remoteRelease!.changes.isNotEmpty) ...[
            const SizedBox(height: 6),
            _SupportCollapsibleBlock(
              key: ValueKey('remote_changes_${remoteRelease!.versionCode}'),
              initiallyExpanded: remoteChangesExpanded,
              onExpansionChanged: (expanded) {
                setState(() => remoteChangesExpanded = expanded);
              },
              title: 'Описание обновления',
              subtitle: 'Нажмите, чтобы посмотреть список изменений',
              titleStyle: body,
              subtitleStyle: text.sectionStyle,
              children: [
                for (final ch in remoteRelease!.changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('• $ch', style: body),
                  ),
              ],
            ),
          ],
        ] else if (hasChecked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Установлена актуальная версия', style: body),
          ),
      ],
    );

    return DefaultTextStyle(
      style: body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          aboutSection,
          changelogSection,
          updateSection,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (consumerContext, app, _) {
        final theme = Theme.of(consumerContext);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final layout = _ChromePanelLayout.fromContext(
          consumerContext,
          app.chromeButtonSize,
        );
        const panelSurface = ChromePanelLightSurface.modalOpaque;
        final text = _ChromeSidePanelTextTheme.create(
          fontSize: app.fontSize,
          lineHeight: app.lineHeight,
          isDark: isDark,
        );
        return ScaffoldMessenger(
          key: _supportSnackMessengerKey,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: FutureBuilder<_SupportDialogData>(
            future: _dataFuture,
            builder: (ctx, snapshot) {
              final loading =
                  snapshot.connectionState != ConnectionState.done;
              return _chromeSidePanelScaffold(
                dialogContext: widget.dialogContext,
                isDark: isDark,
                layout: layout,
                title: 'Техподдержка',
                titleStyle: text.titleStyle,
                lightSurface: panelSurface,
                scrollController: _panelScrollController,
                scrollChild: loading
                    ? SizedBox(
                        height: 140,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: isDark
                                ? BibleDarkPalette.accentGold
                                : BibleLightPalette.settingsGlassPrimary,
                          ),
                        ),
                      )
                    : _buildSupportScroll(
                        consumerContext: consumerContext,
                        layout: layout,
                        theme: theme,
                        scheme: scheme,
                        text: text,
                        isDark: isDark,
                        data: snapshot.data,
                      ),
              );
            },
          ),
        ),
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
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _SupportDialogRouteBody(dialogContext: dialogContext);
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

Widget _helpBullet(String text, TextStyle style) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text('• $text', style: style),
    );

/// Без теней и подчёркиваний — иначе в светлой теме наследуются «жёлтые» линии.
TextStyle _helpPanelPlainStyle(TextStyle base) => TextStyle(
      inherit: false,
      fontSize: base.fontSize,
      fontWeight: base.fontWeight,
      fontStyle: base.fontStyle,
      color: base.color,
      height: base.height,
      letterSpacing: base.letterSpacing,
      decoration: TextDecoration.none,
      decorationColor: null,
      backgroundColor: null,
      shadows: const [],
    );

BorderSide _helpInstructionOutlineSide(bool isDark) => isDark
    ? const BorderSide(color: BibleDarkPalette.cardBorderGold, width: 1)
    : BibleLightPalette.chromePillOutlineSide;

/// Кнопка раздела «Инструкция» — как пункт меню «⋯», без внешнего отступа под «тень».
Widget _helpInstructionMenuButton({
  required BuildContext context,
  required bool isDark,
  required String label,
  required TextStyle labelStyle,
  VoidCallback? onTap,
  bool showClose = false,
  VoidCallback? onClose,
}) {
  final chrome = context.watch<AppProvider>().chromeButtonSize;
  final hPad = (chrome * 0.30).clamp(10.0, 16.0);
  final vPad = (chrome * 0.18).clamp(7.0, 11.0);
  final labelFs = labelStyle.fontSize ?? 14.0;
  final labelLine = labelFs * (labelStyle.height ?? 1.2);
  final minHeight = math.max(
    (chrome * 0.96).clamp(42.0, 62.0),
    labelLine + vPad * 2 + 8,
  );
  final inner = isDark
      ? BibleDarkPalette.cardBg
      : BibleLightPalette.settingsGlassCard;
  final outline = _helpInstructionOutlineSide(isDark);
  final iconColor = isDark
      ? BibleDarkPalette.iconActive
      : BibleLightPalette.settingsGlassPrimary;
  final iconSize = (labelFs * 1.1).clamp(18.0, 30.0);
  const r = _kChromePanelShellRadius;

  return Material(
    color: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    child: Ink(
      decoration: BoxDecoration(
        color: inner,
        borderRadius: BorderRadius.circular(r),
        border: Border.fromBorderSide(outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showClose) ...[
                  SizedBox(width: (chrome * 0.2).clamp(6.0, 12.0)),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.arrow_back,
                        color: iconColor,
                        size: iconSize,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _helpInstructionScrollableContentPanel({
  required bool isDark,
  required ScrollController controller,
  required Widget child,
}) {
  final outline = _helpInstructionOutlineSide(isDark);
  const r = _kChromeSidePanelSectionRadius;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: _chromeSidePanelSectionFill(isDark),
      borderRadius: BorderRadius.circular(r),
      border: Border.fromBorderSide(outline),
    ),
    child: SingleChildScrollView(
      controller: controller,
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: child,
    ),
  );
}

List<Widget> _helpContentBible({
  required TextStyle bodyStyle,
  required TextStyle tocStyle,
}) {
  return [
    Text('Навигация', style: tocStyle),
    const SizedBox(height: 4),
    _helpBullet(
      'Книгу и главу выбирают кнопки в верхней полосе.',
      bodyStyle,
    ),
    _helpBullet(
      'Листать главу за главой можно жестом влево или вправо.',
      bodyStyle,
    ),
    _helpBullet(
      'Долгое касание стиха включает выделение; коротким касанием отмечают ещё стихи.',
      bodyStyle,
    ),
    _helpBullet(
      '«Избранное» в шапке сохраняет выбранные стихи и открывает их перечень.',
      bodyStyle,
    ),
    _helpBullet(
      'Окна выбора книги, главы, поиска и избранного закрываются '
      'системной кнопкой «Назад» или тапом по затемнённой области вокруг окна.',
      bodyStyle,
    ),
    const SizedBox(height: 10),
    Text('Поиск', style: tocStyle),
    const SizedBox(height: 4),
    _helpBullet(
      'Введите одно слово или несколько — поиск выполняется автоматически по мере набора.',
      bodyStyle,
    ),
    _helpBullet(
      'Флажки «ВЗ» и «НЗ» ограничивают поиск Ветхим или Новым Заветом.',
      bodyStyle,
    ),
    _helpBullet(
      'При включённом «Целом слове» находятся только отдельные слова целиком; '
      'если выключить, подойдёт и вхождение внутри слова '
      '(например, по «рад» откроется и «радость»).',
      bodyStyle,
    ),
    _helpBullet(
      'По строке из списка результатов открывается соответствующий стих.',
      bodyStyle,
    ),
  ];
}

List<Widget> _helpContentNotebook({
  required TextStyle bodyStyle,
  required TextStyle tocStyle,
}) {
  return [
    Text('Список файлов и папок', style: tocStyle),
    const SizedBox(height: 4),
    _helpBullet(
      'Стрелка «Назад» слева в папке возвращает к внешнему списку.',
      bodyStyle,
    ),
    _helpBullet(
      '«Новая папка» создаёт каталог там, где вы сейчас просматриваете список.',
      bodyStyle,
    ),
    _helpBullet(
      '«Новый документ» — новая текстовая заметка; после создания откроется редактор.',
      bodyStyle,
    ),
    _helpBullet(
      'Три точки справа в шапке открывают общее меню приложения '
      '(настройки, инструкция, выход и другое).',
      bodyStyle,
    ),
    _helpBullet(
      'В настройках можно сменить тему, шрифт и интервалы в Библии, красные буквы, '
      'величину кнопок панели и включить «Не выключать экран».',
      bodyStyle,
    ),
    _helpBullet(
      'Короткое касание открывает файл или папку.',
      bodyStyle,
    ),
    _helpBullet(
      'Долгое касание файла или папки открывает меню справа: для файла — '
      'поделиться, сохранить копию, переименовать или удалить; '
      'для папки — переименовать или удалить.',
      bodyStyle,
    ),
    _helpBullet(
      'Перемещение файла: долгим касанием откройте меню файла, выберите '
      '«Переместить в…», затем перейдите в нужную папку в дереве и нажмите '
      '«Переместить сюда». Исходная папка отмечена серым цветом.',
      bodyStyle,
    ),
    const SizedBox(height: 8),
    Text('Редактор документа', style: tocStyle),
    const SizedBox(height: 4),
    _helpBullet(
      '«Закрыть» (стрелка) — сохранить изменения и вернуться к списку.',
      bodyStyle,
    ),
    _helpBullet(
      'После паузы в наборе текст автоматически записывается на диск; '
      'кнопка «Сохранить» в шапке сохраняет немедленно.',
      bodyStyle,
    ),
    _helpBullet(
      '«Шаг назад» и «Шаг вперёд» отменяют или возвращают последние правки в тексте.',
      bodyStyle,
    ),
    _helpBullet(
      'В списке при входе в папку внизу показана строка «Папка:» — путь от корня блокнота; '
      'по сегментам пути можно нажимать и быстро переходить в выбранную папку '
      '(с возвратом на нужный уровень).',
      bodyStyle,
    ),
    _helpBullet(
      'В редакторе строка «Документ:» внизу напоминает полный путь к заметке, '
      'со всеми вложенными папками.',
      bodyStyle,
    ),
    _helpBullet(
      'Вертикальные три точки в шапке редактора ведут в то же общее меню приложения.',
      bodyStyle,
    ),
    _helpBullet(
      'Текст набирается во всю ширину экрана; стихи из вкладки «Библия» можно '
      'скопировать и вставить сюда.',
      bodyStyle,
    ),
    _helpBullet(
      'После копирования и вставки текст в буфере сохраняется, '
      'поэтому его можно вставлять повторно при необходимости.',
      bodyStyle,
    ),
  ];
}

List<Widget> _helpContentReadingPlan({
  required TextStyle bodyStyle,
  required TextStyle tocStyle,
  required int n,
}) {
  return [
    _helpBullet(
      'Для годовых планов сначала показаны четыре квартала; для тематических («Вера», «Надежда», «Любовь») — по одному кварталу; '
      'для плана «Для начинающих» — тоже четыре квартала, но с поэтапным маршрутом для новичка. '
      'Число дней в маршруте: «Вера» и «Надежда» — $kFaithPlanDayCount, «Любовь» — $kLovePlanDayCount. '
      'Внутри квартала — дни подряд (для годовых планов номера 1…$n по году; для тематических — дни по номерам этого маршрута). '
      'На экране кварталов в шапке — выбор плана и меню; внутри квартала — прокрутка списка '
      'и переход к началу или концу перечня.',
      bodyStyle,
    ),
    const SizedBox(height: 8),
    Text('Параллельный план', style: tocStyle),
    const SizedBox(height: 4),
    Text(
      'Ветхий Завет, Псалтирь и Новый Завет читаются рядом, по заранее выстроенному '
      'порядку глав на каждый день. Нумерация дней идёт подряд (1…$n), без привязки к датам '
      'календаря. Отметки «прочитано» хранятся на вашем устройстве.',
      style: bodyStyle,
    ),
    const SizedBox(height: 10),
    Text('Хронологический план', style: tocStyle),
    const SizedBox(height: 4),
    Text(
      'Здесь порядок глав приближён к ходу событий и к сопутствующим текстам. '
      'Дни снова идут подряд (1…$n), вне календарных дат. '
      'Отметки «прочитано» не смешиваются с параллельным планом.',
      style: bodyStyle,
    ),
    const SizedBox(height: 10),
    Text('Последовательный план', style: tocStyle),
    const SizedBox(height: 4),
    Text(
      'Все книги и главы Библии по каноническому порядку (от Бытия до Откровения) '
      'равномерно распределены по $n дням. Отметки «прочитано» хранятся отдельно от '
      'параллельного и хронологического планов.',
      style: bodyStyle,
    ),
    const SizedBox(height: 10),
    Text(
      'Тематические планы («Вера», «Надежда», «Любовь»)',
      style: tocStyle,
    ),
    const SizedBox(height: 4),
    Text(
      'У каждого тематического плана — маршрут из нескольких дней ($kFaithPlanDayCount или $kLovePlanDayCount) с темой и пояснениями к отрывкам: '
      'на экране выбора один квартал и блок советов по чтению. В списке дней слева — ссылки на стихи, '
      'справа — краткая мысль. Отметки «прочитано» для каждого тематического плана хранятся раздельно и отдельно от остальных планов.',
      style: bodyStyle,
    ),
    const SizedBox(height: 10),
    Text('План «Для начинающих»', style: tocStyle),
    const SizedBox(height: 4),
    Text(
      'Этот план разбит на четыре последовательных квартала для плавного входа в чтение: '
      '1-й квартал — Евангелие от Иоанна, 2-й — Деяния, 3-й — Римлянам, 4-й — Галатам. '
      'Внутри каждого квартала дни идут по порядку, с отдельным прогрессом по дням и кварталам. '
      'Отметки «прочитано» в плане «Для начинающих» хранятся отдельно от всех остальных планов.',
      style: bodyStyle,
    ),
  ];
}

class _HelpInstructionSection {
  const _HelpInstructionSection({
    required this.id,
    required this.title,
    required this.buildContent,
  });

  final String id;
  final String title;
  final List<Widget> Function() buildContent;
}

class _HelpDialogRouteBody extends StatefulWidget {
  const _HelpDialogRouteBody({required this.dialogContext});

  final BuildContext dialogContext;

  @override
  State<_HelpDialogRouteBody> createState() => _HelpDialogRouteBodyState();
}

class _HelpDialogRouteBodyState extends State<_HelpDialogRouteBody> {
  String? _selectedSectionId;
  final ScrollController _contentScrollController = ScrollController();

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  void _openSection(String id) {
    setState(() => _selectedSectionId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_contentScrollController.hasClients) {
        _contentScrollController.jumpTo(0);
      }
    });
  }

  void _closeSection() {
    setState(() => _selectedSectionId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (consumerContext, app, _) {
        final isDark = Theme.of(consumerContext).brightness == Brightness.dark;
        const panelSurface = ChromePanelLightSurface.modalOpaque;
        final layout = _ChromePanelLayout.fromContext(
          consumerContext,
          app.chromeButtonSize,
        );
        final text = _ChromeSidePanelTextTheme.create(
          fontSize: app.fontSize,
          lineHeight: app.lineHeight,
          isDark: isDark,
          glassTypography: false,
        );
        final helpAccentColor = isDark
            ? BibleDarkPalette.titleGold
            : BibleLightPalette.primaryDark;
        final bodyStyle = _helpPanelPlainStyle(text.bodyStyle);
        final tocStyle = _helpPanelPlainStyle(
          text.tocStyle.copyWith(color: helpAccentColor),
        );
        final titleStyle = _helpPanelPlainStyle(
          text.titleStyle.copyWith(color: helpAccentColor),
        );
        const n = 365;
        final pillLabelStyle = _helpPanelPlainStyle(
          text.sectionStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: helpAccentColor,
          ),
        );

        final sections = <_HelpInstructionSection>[
          _HelpInstructionSection(
            id: 'bible',
            title: 'Библия',
            buildContent: () => _helpContentBible(
              bodyStyle: bodyStyle,
              tocStyle: tocStyle,
            ),
          ),
          _HelpInstructionSection(
            id: 'notebook',
            title: 'Блокнот',
            buildContent: () => _helpContentNotebook(
              bodyStyle: bodyStyle,
              tocStyle: tocStyle,
            ),
          ),
          _HelpInstructionSection(
            id: 'reading_plan',
            title: 'План чтения',
            buildContent: () => _helpContentReadingPlan(
              bodyStyle: bodyStyle,
              tocStyle: tocStyle,
              n: n,
            ),
          ),
        ];

        _HelpInstructionSection? selected;
        if (_selectedSectionId != null) {
          for (final section in sections) {
            if (section.id == _selectedSectionId) {
              selected = section;
              break;
            }
          }
        }

        final pinnedBelowTitle = selected == null
            ? const <Widget>[]
            : <Widget>[
                _helpInstructionMenuButton(
                  context: consumerContext,
                  isDark: isDark,
                  label: selected.title,
                  labelStyle: pillLabelStyle,
                  showClose: true,
                  onClose: _closeSection,
                ),
                const SizedBox(height: 6),
              ];

        final scrollChild = selected == null
            ? SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      _helpInstructionMenuButton(
                        context: consumerContext,
                        isDark: isDark,
                        label: sections[i].title,
                        labelStyle: pillLabelStyle,
                        onTap: () => _openSection(sections[i].id),
                      ),
                      if (i < sections.length - 1) const SizedBox(height: 4),
                    ],
                  ],
                ),
              )
            : _helpInstructionScrollableContentPanel(
                isDark: isDark,
                controller: _contentScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: selected.buildContent(),
                ),
              );

        return _chromeSidePanelScaffold(
          dialogContext: widget.dialogContext,
          isDark: isDark,
          layout: layout,
          title: 'Инструкция',
          titleStyle: titleStyle,
          lightSurface: panelSurface,
          pinnedBelowTitle: pinnedBelowTitle,
          embedScrollChild: selected != null,
          scrollChild: scrollChild,
        );
      },
    );
  }
}

void showAppHelpDialog(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _HelpDialogRouteBody(dialogContext: dialogContext);
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
