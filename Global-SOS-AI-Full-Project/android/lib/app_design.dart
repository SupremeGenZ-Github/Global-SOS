import 'package:flutter/material.dart';

ThemeData buildSafetyTheme({required bool light, required bool contrast}) {
  final brightness = light ? Brightness.light : Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: light ? const Color(0xff1559dc) : const Color(0xff73a8ff),
    brightness: brightness,
    surface: light ? Colors.white : const Color(0xff0c0e12),
  ).copyWith(
    primary: light ? const Color(0xff1559dc) : const Color(0xff8ab7ff),
    onPrimary: light ? Colors.white : const Color(0xff061b3c),
    error: light ? const Color(0xffba233d) : const Color(0xffff798b),
    outline: contrast ? (light ? Colors.black : Colors.white) : (light ? const Color(0xffcbd4e3) : const Color(0xff343b48)),
    outlineVariant: contrast ? (light ? Colors.black : Colors.white) : (light ? const Color(0xffe2e8f2) : const Color(0xff242a34)),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final text = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.15),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 21, fontWeight: FontWeight.w700, height: 1.25),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: light ? const Color(0xfff7f9fd) : Colors.black,
    appBarTheme: AppBarTheme(backgroundColor: light ? const Color(0xfff7f9fd) : Colors.black,
      foregroundColor: scheme.onSurface, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: text.titleLarge, toolbarHeight: 68),
    cardTheme: CardThemeData(elevation: 0, color: scheme.surface,
      margin: const EdgeInsets.only(bottom: 14), clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: scheme.outlineVariant))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: light ? Colors.white : const Color(0xff151922),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size(48, 50), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(minimumSize: const Size(48, 50))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      side: BorderSide(color: scheme.outline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 44))),
    navigationBarTheme: NavigationBarThemeData(height: 76, elevation: 0,
      backgroundColor: scheme.surface, indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w600))),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 24),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: text.titleLarge, contentTextStyle: text.bodyMedium),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: scheme.outlineVariant), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
  );
}

class SafetyFeature extends StatelessWidget {
  const SafetyFeature({super.key, required this.icon, required this.title, required this.caption, required this.onTap});
  final IconData icon;
  final String title, caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 24)),
        const SizedBox(height: 14), Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5), Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    ))),
  );
}

class SafetyFeatureGrid extends StatelessWidget {
  const SafetyFeatureGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final wideText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final columns = constraints.maxWidth >= 660 ? 4 : constraints.maxWidth >= 300 && !wideText ? 2 : 1;
    final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
    return Wrap(spacing: 12, runSpacing: 12, children: children.map((child) => SizedBox(width: width, child: child)).toList());
  });
}

class SafetySectionHeading extends StatelessWidget {
  const SafetySectionHeading({super.key, required this.title, this.description});
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 10, bottom: 16), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (description != null) ...[const SizedBox(height: 6), Text(description!, style: Theme.of(context).textTheme.bodyMedium)],
    ],
  ));
}
