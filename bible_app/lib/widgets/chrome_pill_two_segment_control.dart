import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';

/// Двухсегментный переключатель в овальной панели (как ВЗ/НЗ в поиске).
class ChromePillTwoSegmentControl<T> extends StatelessWidget {
  const ChromePillTwoSegmentControl({
    super.key,
    required this.value,
    required this.leftValue,
    required this.rightValue,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
    required this.isDark,
    this.rowHeight = 40,
    this.fontSize = 14,
    this.leftIcon,
    this.rightIcon,
    this.trackColor,
    this.activeColor,
    this.activeForegroundColor,
    this.inactiveForegroundColor,
    this.borderColor,
    this.labelShadows,
  });

  final T value;
  final T leftValue;
  final T rightValue;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<T> onChanged;
  final bool isDark;
  final double rowHeight;
  final double fontSize;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final Color? trackColor;
  final Color? activeColor;
  final Color? activeForegroundColor;
  final Color? inactiveForegroundColor;
  final Color? borderColor;
  final List<Shadow>? labelShadows;

  @override
  Widget build(BuildContext context) {
    final segmentInset = (rowHeight * 0.085).clamp(3.0, 4.5);
    final innerRadius = (rowHeight - 2 * segmentInset) / 2;
    final panelRadius = rowHeight / 2;
    final resolvedTrack = trackColor ??
        (isDark
            ? const Color(0xFF37474F)
            : BibleLightPalette.disabledBg);
    final resolvedActive = activeColor ??
        (isDark ? const Color(0xFF81D4FA) : BibleLightPalette.primary);
    final activeFg =
        activeForegroundColor ?? (isDark ? Colors.black87 : Colors.white);
    final inactiveFg = inactiveForegroundColor ??
        (isDark ? Colors.white70 : BibleLightPalette.secondaryText);
    final resolvedBorder = borderColor ??
        (isDark
            ? ChromeOutline.color
            : BibleLightPalette.chromePillOutlineColor);
    final labelStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.15,
      decoration: TextDecoration.none,
      backgroundColor: null,
      shadows: labelShadows,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTrack,
        borderRadius: BorderRadius.circular(panelRadius),
        border: Border.all(
          color: resolvedBorder,
          width: ChromeOutline.width,
        ),
      ),
      child: SizedBox(
        height: rowHeight,
        child: Padding(
          padding: EdgeInsets.all(segmentInset),
          child: Row(
            children: [
              Expanded(
                child: _Segment(
                  label: leftLabel,
                  icon: leftIcon,
                  selected: value == leftValue,
                  borderRadius: BorderRadius.circular(innerRadius),
                  activeColor: resolvedActive,
                  activeFg: activeFg,
                  inactiveFg: inactiveFg,
                  labelStyle: labelStyle,
                  onTap: () => onChanged(leftValue),
                ),
              ),
              SizedBox(width: segmentInset),
              Expanded(
                child: _Segment(
                  label: rightLabel,
                  icon: rightIcon,
                  selected: value == rightValue,
                  borderRadius: BorderRadius.circular(innerRadius),
                  activeColor: resolvedActive,
                  activeFg: activeFg,
                  inactiveFg: inactiveFg,
                  labelStyle: labelStyle,
                  onTap: () => onChanged(rightValue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.borderRadius,
    required this.activeColor,
    required this.activeFg,
    required this.inactiveFg,
    required this.labelStyle,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final BorderRadius borderRadius;
  final Color activeColor;
  final Color activeFg;
  final Color inactiveFg;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? activeFg : inactiveFg;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: borderRadius,
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 14,
                      spreadRadius: 0,
                      color: activeColor.withValues(alpha: 0.45),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: labelStyle.fontSize! * 1.15, color: fg),
                SizedBox(width: labelStyle.fontSize! * 0.35),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
