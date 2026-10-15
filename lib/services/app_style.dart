import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system for Brightly.
///
/// Visual language: deep black canvas with neon green as the single accent
/// colour. Dark mode is pitch-black; light mode is a dark grey that still
/// feels "techy" but lighter enough to distinguish. Every surface is separated
/// by faint borders rather than elevation.
class AppStyle {
  AppStyle._();

  // ══════════════════════════════════════════════════════════════════
  // Brand colours — Black & Lime Combo (`#000000` & `#C6FF33`)
  //
  // `#000000` (True Black)
  // `#C6FF33` (Lime Neon Accent)
  // ══════════════════════════════════════════════════════════════════
  static const Color ink = Color(0xFF121212);
  static const Color inkSoft = Color(0xFF1F1F1F);
  static const Color spark = Color(0xFFCEEB45);
  static const Color sparkSoft = Color(0xFFDAF266);
  static const Color lime = Color(0xFFCEEB45);
  static const Color lavender = Color(0xFF1A260D);

  // Accent roles kept under their legacy names so call sites stay valid.
  static const Color coral = Color(0xFFFF5252);
  static const Color sunny = Color(0xFFFFD166);
  static const Color periwinkle = Color(0xFF1A260D);
  static const Color mint = Color(0xFFCEEB45);
  static const Color lilac = lavender;

  // ══════════════════════════════════════════════════════════════════
  // Surfaces
  // ══════════════════════════════════════════════════════════════════
  static const Color cream = Color(0xFFF2F5ED);   // light mode canvas
  static const Color paper = Color(0xFFFFFFFF);    // light mode card
  static const Color sand = Color(0xFFDCE2D1);     // light mode secondary

  static const Color inkDark = Color(0xFF121212);  // dark mode canvas (#121212)
  static const Color paperDark = Color(0xFF0D0D0D);// dark mode card
  static const Color sandDark = Color(0xFF161616);  // dark mode secondary
  static const Color lineDark = Color(0xFF222222);  // dark mode border

  // ══════════════════════════════════════════════════════════════════
  // Semantic
  // ══════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFEF5D5D);
  static const Color warning = Color(0xFFFFC24B);

  // ── Legacy aliases kept so existing call sites stay valid ──
  static const Color primaryBlue = spark;
  static const Color accentOrange = Color(0xFF4ADE80);
  static const Color primaryIndigo = spark;
  static const Color secondaryBlue = sparkSoft;
  static const Color deepBlue = ink;
  static const Color successGreen = success;
  static const Color errorRed = danger;
  static const Color warningAmber = warning;
  static const Color secondarySlate = Color(0xFF888888);
  static const Color slateBgLight = cream;
  static const Color slateBgDark = inkDark;
  static const Color cardDark = paperDark;
  static const Color borderDark = lineDark;

  // ══════════════════════════════════════════════════════════════════
  // Shape scale
  //
  // Slightly tighter than the previous set: the reference relies on hairline
  // borders for separation, and very large radii start to look bubbly rather
  // than precise once the fills are flat.
  // ══════════════════════════════════════════════════════════════════
  static const double rXs = 8;
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 22;
  static const double rXl = 30;
  static const double rPill = 999;

  // ══════════════════════════════════════════════════════════════════
  // Context helpers
  // ══════════════════════════════════════════════════════════════════
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color getBackgroundColor(BuildContext context) =>
      isDark(context) ? inkDark : cream;

  static Color getCardColor(BuildContext context) =>
      isDark(context) ? paperDark : paper;

  static Color getSandColor(BuildContext context) =>
      isDark(context) ? sandDark : sand;

  static Color getTextColor(BuildContext context) =>
      isDark(context) ? const Color(0xFFE8E8E8) : ink;

  static Color getSubtitleColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF777777) : const Color(0xFF666666);

  static Color getBorderColor(BuildContext context) =>
      isDark(context) ? lineDark : const Color(0xFFD5D5D5);

  static Color getPrimaryBlue(BuildContext context) => ink;

  // ══════════════════════════════════════════════════════════════════
  // Gradients & shadows
  // ══════════════════════════════════════════════════════════════════
  static LinearGradient getGradient(BuildContext context) {
    if (isDark(context)) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFCEEB45), Color(0xFF121212)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFCEEB45), Color(0xFF141414)],
    );
  }

  /// A subtle two-stop ramp for hero surfaces.
  ///
  /// Only used on the few large brand surfaces (login hero, splash mark). List
  /// cards and tiles use flat fills with hairline borders instead, because a
  /// gradient per card is the fastest way to make a dense list look cluttered.
  static LinearGradient gradientOf(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [color, Color.lerp(color, Colors.black, 0.16)!],
  );

  /// Hero / stat surface colours. Blue leads because it is the brand; the rest
  /// are muted enough to sit behind numbers without competing.
  static const List<Color> blockColors = <Color>[
    spark,
    ink,
    Color(0xFF133D79),
    Color(0xFFEDCC1D),
  ];

  /// Hairline elevation for cards sitting on the canvas.
  ///
  /// Deliberately weak. The reference separates surfaces with a 1px border, so
  /// the shadow only needs to stop the card from looking pasted on.
  static List<BoxShadow> softShadow(BuildContext context) {
    if (isDark(context)) {
      return const <BoxShadow>[
        BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
      ];
    }
    return const <BoxShadow>[
      BoxShadow(color: Color(0x0D111827), blurRadius: 16, offset: Offset(0, 4)),
    ];
  }

  /// Reserved for elements that genuinely float (nav bar, FAB, dialog).
  static List<BoxShadow> liftShadow(BuildContext context, {Color? tint}) {
    final base = isDark(context) ? Colors.black : (tint ?? ink);
    return <BoxShadow>[
      BoxShadow(
        color: base.withValues(alpha: 0.16),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> cardShadow(BuildContext context) =>
      softShadow(context);

  /// A soft tinted fill that reads on both light and dark canvases.
  static Color tint(Color color, [double opacity = 0.12]) => color.withValues(
    alpha: opacity,
  );

  // ══════════════════════════════════════════════════════════════════
  // Safe-area helpers
  // ══════════════════════════════════════════════════════════════════

  /// Top inset reserved for the status bar / notch, plus a comfortable gap.
  ///
  /// Headers used to sit flush against the system status bar on phones with a
  /// notch, so every screen now starts below it.
  static double topInset(BuildContext context, {double gap = 14}) {
    final pad = MediaQuery.maybePaddingOf(context);
    final inset = pad?.top ?? 0;
    // Ignore the tall inset in landscape / desktop so content does not float.
    final usable = inset > 48 ? inset * 0.5 : inset;
    return usable + gap;
  }

  /// Bottom inset for the home indicator / gesture bar.
  static double bottomInset(BuildContext context, {double gap = 14}) {
    final pad = MediaQuery.maybePaddingOf(context);
    final inset = pad?.bottom ?? 0;
    return inset > 24 ? inset : inset + gap;
  }

  /// Standard horizontal screen gutter.
  static const double gutter = 20;

  /// Identifies the bottom navigation bar so tests and callers can scope
  /// finders to it instead of matching bare label text on the page.
  static const Key bottomNavKey = Key('app-bottom-nav');

  // ══════════════════════════════════════════════════════════════════
  // Typography
  // ══════════════════════════════════════════════════════════════════
  static TextStyle font(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
    double? spacing,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color ?? getTextColor(context),
    height: height,
    letterSpacing: spacing,
  );

  /// Big friendly numerals used in stat bubbles and hero cards.
  static TextStyle numeral(
    BuildContext context, {
    double size = 30,
    Color? color,
    FontWeight weight = FontWeight.w800,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color ?? getTextColor(context),
    height: 1,
    letterSpacing: -1.4,
  );

  static TextStyle overline(BuildContext context, {Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: color ?? getSubtitleColor(context),
      );

  // ══════════════════════════════════════════════════════════════════
  // Decoration
  // ══════════════════════════════════════════════════════════════════

  /// Wraps content with the canvas colour.
  ///
  /// No decorative blobs: the previous version scattered soft circles behind
  /// every screen, which is the single biggest reason the app read as playful
  /// rather than professional. Surfaces are now separated by borders instead.
  static Widget background({
    required BuildContext context,
    required Widget child,
  }) {
    return ColoredBox(color: getBackgroundColor(context), child: child);
  }

  /// A small four-point sparkle — echoes the logo without shouting.
  ///
  /// Only for hero and empty states; list rows stay undecorated so dense data
  /// remains scannable.
  static Widget sparkles({
    double size = 14,
    Color color = spark,
    int count = 3,
  }) {
    return SizedBox(
      width: size * count,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          count,
          (i) => SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _SparkPainter(color: color, opacity: 1 - i * 0.22),
            ),
          ),
        ),
      ),
    );
  }

  /// A dashed progress arc, borrowed from the reference's ring motif.
  static Widget dashedArc({
    required double progress,
    double size = 60,
    Color color = spark,
    Color track = sand,
    double stroke = 5,
    Widget? child,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DashedArcPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
          track: track,
          stroke: stroke,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Shared components
  // ══════════════════════════════════════════════════════════════════

  /// Floating bottom navigation.
  ///
  /// Was a full-bleed dark pill that expanded to show the selected label. On a
  /// cool grey canvas that read as a heavy black bar cutting the screen in
  /// half. It is now a white card with a hairline border, and selection is
  /// shown by a filled blue icon tile plus a persistent label.
  ///
  /// Labels are always visible rather than only on the active tab: hiding them
  /// makes the bar change width as you move between tabs, which feels unstable.
  static Widget darkNavBar({
    required BuildContext context,
    required int index,
    required List<NavItem> items,
    required ValueChanged<int> onTap,
    double? bottom,
  }) {
    final dark = isDark(context);
    return Positioned(
      left: gutter,
      right: gutter,
      bottom: bottom ?? bottomInset(context),
      child: Container(
        key: bottomNavKey,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0A0A0A) : paper,
          borderRadius: BorderRadius.circular(rLg),
          border: Border.all(color: getBorderColor(context), width: 1),
          boxShadow: liftShadow(context),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _navItem(
                  items[i],
                  i == index,
                  () => onTap(i),
                  dark: dark,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _navItem(
    NavItem item,
    bool selected,
    VoidCallback onTap, {
    bool dark = false,
  }) {
    // Labels resolve from the passed `dark` flag rather than a context, since
    // this helper is static and has no BuildContext of its own.
    final labelColor = selected
        ? spark
        : (dark ? const Color(0xFF666666) : const Color(0xFF888888));

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(rSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? spark.withValues(alpha: dark ? 0.22 : 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(rPill),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 20,
                  color: selected ? spark : labelColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rounded circular action button used in headers.
  static Widget circleButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Color? background,
    double size = 42,
    double iconSize = 19,
    bool bordered = true,
  }) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background ?? getCardColor(context),
              shape: BoxShape.circle,
              border: bordered
                  ? Border.all(color: getBorderColor(context), width: 1.4)
                  : null,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? getTextColor(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Notification bell with an unread dot.
  static Widget bellButton({
    required BuildContext context,
    required VoidCallback onTap,
    bool hasUnread = false,
    double size = 42,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: circleButton(
              context: context,
              icon: hasUnread
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              onTap: onTap,
              iconColor: hasUnread ? coral : getTextColor(context),
              size: size,
            ),
          ),
          if (hasUnread)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: getBackgroundColor(context), width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Circular avatar built from initials.
  static Widget avatar({
    required BuildContext context,
    required String name,
    double size = 46,
  }) {
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark(context) ? sandDark : lavender,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final only = parts.first;
      return only.substring(0, only.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Rounded search field with a clear button.
  static Widget searchField({
    required BuildContext context,
    TextEditingController? controller,
    FocusNode? focusNode,
    required ValueChanged<String> onChanged,
    VoidCallback? onCleared,
    String hint = 'Cari beasiswa...',
  }) {
    return searchFieldPill(
      context: context,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onCleared: onCleared,
      hint: hint,
    );
  }

  /// Segmented pill selector (Weekly / Month style).
  static Widget segmentedPills({
    required BuildContext context,
    required List<String> labels,
    required int index,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: getSandColor(context),
        borderRadius: BorderRadius.circular(rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: i == index ? getCardColor(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(rPill),
                  boxShadow: i == index ? softShadow(context) : null,
                ),
                child: Text(
                  labels[i],
                  style: font(
                    context,
                    size: 12.5,
                    weight: FontWeight.w800,
                    color: i == index ? ink : getSubtitleColor(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Section heading.
  ///
  /// The colour dash that used to sit before every title was dropped: repeated
  /// on each screen it read as a template. Weight and size carry the hierarchy
  /// now, and `trailing` becomes an actionable "See all" affordance.
  static Widget sectionTitle(
    BuildContext context, {
    required String title,
    String? trailing,
    Widget? trailingWidget,
    VoidCallback? onTrailingTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: font(context, size: 16, weight: FontWeight.w800, spacing: -0.3),
          ),
        ),
        if (trailing != null)
          InkWell(
            onTap: onTrailingTap,
            borderRadius: BorderRadius.circular(rPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                trailing,
                style: font(
                  context,
                  size: 12,
                  weight: FontWeight.w700,
                  color: spark,
                ),
              ),
            ),
          ),
        ?trailingWidget,
      ],
    );
  }

  /// Small label chip (S1, Full Funded, ...).
  static Widget chip(
    BuildContext context, {
    required String label,
    Color color = ink,
    bool solid = false,
    IconData? icon,
  }) {
    final dark = isDark(context);
    final fg = solid
        ? (color.computeLuminance() > 0.55 ? ink : Colors.white)
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: dark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(rSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          // Flexible + ellipsis: long funding strings ("Fully Funded
          // International Programme") used to overflow narrow cards.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: font(
                context,
                size: 10.5,
                weight: FontWeight.w800,
                color: fg,
                spacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stat tile — a white card with a large numeral and a muted caption.
  ///
  /// The reference's signature move is a big number on a flat surface. It is
  /// kept, but the icon moves above the numeral at low alpha so the number
  /// stays the loudest thing in the tile.
  static Widget statBubble({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    Color color = spark,
    double size = 96,
    bool compact = false,
  }) {
    return Container(
      width: size,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 14 : 16,
        horizontal: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(rLg),
        border: Border.all(color: getBorderColor(context), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 16 : 18, color: color),
          SizedBox(height: compact ? 8 : 10),
          Text(
            value,
            style: numeral(
              context,
              size: compact ? 20 : 26,
              color: getTextColor(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: font(
              context,
              size: compact ? 10.5 : 11,
              weight: FontWeight.w600,
              color: getSubtitleColor(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Friendly empty state with a playful icon.
  static Widget emptyState({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Color color = periwinkle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 34, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: font(context, size: 16.5, weight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: font(
                  context,
                  size: 13,
                  weight: FontWeight.w500,
                  color: getSubtitleColor(context),
                  height: 1.55,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action],
          ],
        ),
      ),
    );
  }

  /// Primary filled action button.
  static Widget primaryButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color color = spark,
    bool loading = false,
    bool expanded = true,
  }) {
    final fg = color.computeLuminance() > 0.55 ? ink : Colors.white;

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            // max when the button spans the full width so `Flexible` can
            // ellipsize a long label instead of overflowing.
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: font(context, size: 15, weight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(rPill),
        child: Ink(
          height: 54,
          width: expanded ? double.infinity : null,
          padding: expanded
              ? const EdgeInsets.symmetric(horizontal: 20)
              : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(rPill),
            boxShadow: liftShadow(context, tint: color),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// One entry in the dark pill navigation bar.
@immutable
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

/// Headers shared across screens.
extension AppHeaders on AppStyle {
  /// Friendly greeting header used on Home.
  ///
  /// Mirrors the reference's "Hi, Elizabeth 👋" row: avatar, name, bell, and a
  /// full-width pill search underneath.
  static Widget greeting({
    required BuildContext context,
    required String name,
    required String subtitle,
    Widget? avatarSlot,
    Widget? bellSlot,
    TextEditingController? searchController,
    FocusNode? searchFocusNode,
    void Function(String)? onSearchChanged,
    VoidCallback? onSearchCleared,
    String searchHint = 'Cari beasiswa, negara, jenjang...',
    bool showSearch = true,
  }) {
    return Padding(
      // Sits below the status bar / notch instead of hugging it.
      padding: EdgeInsets.fromLTRB(
        AppStyle.gutter,
        AppStyle.topInset(context),
        AppStyle.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              avatarSlot ??
                  AppStyle.avatar(context: context, name: name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reference reads "Good morning, Alex!" — greeting and name
                    // on one line, with the name carrying the emphasis.
                    Text(
                      '$subtitle, $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.font(
                        context,
                        size: 15,
                        weight: FontWeight.w800,
                        spacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              ?bellSlot,
            ],
          ),
          if (showSearch) ...[
            const SizedBox(height: 16),
            AppStyle.searchField(
              context: context,
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged ?? (_) {},
              onCleared: onSearchCleared,
              hint: searchHint,
            ),
          ],
        ],
      ),
    );
  }

  /// Header for inner screens — back button, bold title, optional action.
  static Widget pageHeader({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    bool showSearch = false,
    TextEditingController? searchController,
    FocusNode? searchFocusNode,
    void Function(String)? onSearchChanged,
    VoidCallback? onSearchCleared,
    String searchHint = 'Cari...',
    double? topPadding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppStyle.gutter,
        topPadding ?? AppStyle.topInset(context),
        AppStyle.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null)
                leading
              else
                AppStyle.circleButton(
                  context: context,
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                  size: 42,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.font(
                        context,
                        size: 19,
                        weight: FontWeight.w800,
                        spacing: -0.4,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyle.font(
                          context,
                          size: 12,
                          weight: FontWeight.w500,
                          color: AppStyle.getSubtitleColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing],
            ],
          ),
          if (showSearch) ...[
            const SizedBox(height: 16),
            AppStyle.searchField(
              context: context,
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged ?? (_) {},
              onCleared: onSearchCleared,
              hint: searchHint,
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Painters
// ══════════════════════════════════════════════════════════════════

class _SparkPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _SparkPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w / 2, h / 2, w, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, h)
      ..quadraticBezierTo(w / 2, h / 2, 0, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color || old.opacity != opacity;
}

class _DashedArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  _DashedArcPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    const dashes = 14;
    final sweep = (math.pi * 2) / dashes;
    final filled = (dashes * progress).round();

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < filled; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(_DashedArcPainter old) =>
      old.progress != progress || old.color != color;
}
