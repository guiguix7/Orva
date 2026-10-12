import 'package:flutter/material.dart';

import '../theme/orva_theme.dart';

class OrvaPageHeader extends StatelessWidget {
  const OrvaPageHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class OrvaSectionHeader extends StatelessWidget {
  const OrvaSectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.trailing});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      ?trailing,
      if (actionLabel != null && onAction != null)
        TextButton(onPressed: onAction, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(actionLabel!)),
    ]);
  }
}

class OrvaSurface extends StatelessWidget {
  const OrvaSurface({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (isDark ? OrvaColors.darkSurface : OrvaColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? OrvaColors.darkBorder : OrvaColors.border),
      ),
      child: child,
    );
    if (onTap == null) return surface;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: surface));
  }
}

class OrvaEmptyState extends StatelessWidget {
  const OrvaEmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction, this.compact = false});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: compact ? 44 : 54,
        height: compact ? 44 : 54,
        decoration: BoxDecoration(color: OrvaColors.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: OrvaColors.primary, size: compact ? 22 : 26),
      ),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.add, size: 18), label: Text(actionLabel!)),
      ],
    ]);
    return Padding(padding: EdgeInsets.all(compact ? 16 : 26), child: Center(child: content));
  }
}

Future<bool> confirmAction(BuildContext context, {required String title, required String message, String actionLabel = 'Confirmar', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: OrvaColors.error) : null,
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showOrvaError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível concluir: $error')));
}

void showOrvaMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '${remaining}min';
  if (remaining == 0) return '${hours}h';
  return '${hours}h ${remaining}min';
}

String formatClock(int minuteOfDay) {
  final h = minuteOfDay ~/ 60;
  final m = minuteOfDay % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String? stringValue(Object? value) => value?.toString();
int intValue(Object? value, [int fallback = 0]) => value is num ? value.toInt() : fallback;
double doubleValue(Object? value, [double fallback = 0]) => value is num ? value.toDouble() : fallback;
