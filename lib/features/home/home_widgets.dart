import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/calendar_layout.dart';
import '../../core/domain/home_overview.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/theme/orva_tokens.dart';
import '../../core/widgets/orva_widgets.dart';

/// Presentation layer for the Home command center. Every number rendered here
/// comes from records already loaded by [HomePage]; these widgets never invent
/// progress or persist anything themselves.

const _hairlineAlpha = 0.9;

Color _hairline(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return (isDark ? OrvaColors.darkBorder : OrvaColors.border).withValues(
    alpha: _hairlineAlpha,
  );
}

Color _surfaceColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? OrvaColors.darkSurface
    : OrvaColors.surface;

TextStyle _micro(BuildContext context, {Color? color, double size = 10.5}) {
  final base = Theme.of(context).textTheme.bodySmall;
  return TextStyle(
    fontSize: size,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: color ?? OrvaColors.tertiaryText,
    fontFamily: base?.fontFamily,
    fontFamilyFallback: base?.fontFamilyFallback,
  );
}

String capitalizeFirst(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onOpenCalendar,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: OrvaColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.spa_outlined, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Text(
          'orva',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Abrir calendário',
          onPressed: onOpenCalendar,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.calendar_month_outlined, size: 21),
        ),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: onOpenSettings,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.tune_rounded, size: 21),
        ),
      ],
    );
  }
}

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({
    super.key,
    required this.greeting,
    required this.name,
    required this.dateLabel,
    required this.isWeekend,
  });

  final String greeting;
  final String? name;
  final String dateLabel;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    final hasName = name != null && name!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isWeekend ? OrvaColors.terracotta : OrvaColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                dateLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _micro(context, color: OrvaColors.secondaryText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            text: greeting,
            children: [
              if (hasName)
                TextSpan(
                  text: ',\n${name!.trim()}',
                  style: const TextStyle(color: OrvaColors.tertiaryText),
                ),
            ],
          ),
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 33, height: 1.08, letterSpacing: -1.1),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.overview,
    required this.checklist,
    required this.onPlanDay,
    required this.onAddTask,
    required this.onOpenCalendar,
  });

  final HomeOverview overview;
  final ChecklistDigest checklist;
  final VoidCallback onPlanDay;
  final VoidCallback onAddTask;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1E302C) : OrvaColors.primary900;
    final muted = const Color(0xFFAFC7C2);
    final faint = const Color(0xFF87A29D);
    final openDay = !overview.hasEntries && checklist.total == 0;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(OrvaRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SEU DIA', style: _micro(context, color: muted)),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpenCalendar,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.82),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 15),
                label: const Text(
                  'Calendário',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (openDay)
            _OpenDayHero(onPlanDay: onPlanDay, onAddTask: onAddTask)
          else ...[
            _DayMetrics(overview: overview, muted: muted, faint: faint),
            const SizedBox(height: 20),
            _DayRibbon(overview: overview),
            const SizedBox(height: 7),
            Row(
              children: [
                for (final label in const ['00h', '06h', '12h', '18h', '24h'])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: label == '00h'
                          ? TextAlign.left
                          : label == '24h'
                          ? TextAlign.right
                          : TextAlign.center,
                      style: orvaMonoStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: faint,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _HeroStat(
                  icon: Icons.timelapse_rounded,
                  label: '${formatMinutes(overview.freeMinutes)} livres',
                  color: muted,
                ),
                if (overview.remainingPlannedMinutes > 0)
                  _HeroStat(
                    icon: Icons.south_east_rounded,
                    label:
                        '${formatMinutes(overview.remainingPlannedMinutes)} por vir',
                    color: muted,
                  ),
                if (overview.conflictCount > 0)
                  _HeroStat(
                    icon: Icons.warning_amber_rounded,
                    label:
                        '${overview.conflictCount} ${overview.conflictCount == 1 ? 'conflito' : 'conflitos'}',
                    color: OrvaColors.mustard,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
          const SizedBox(height: 12),
          if (checklist.total > 0)
            _HeroChecklist(digest: checklist)
          else
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 15, color: faint),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Nenhuma tarefa para hoje',
                    style: TextStyle(fontSize: 12.5, color: faint),
                  ),
                ),
                TextButton(
                  onPressed: onAddTask,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Adicionar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OpenDayHero extends StatelessWidget {
  const _OpenDayHero({required this.onPlanDay, required this.onAddTask});

  final VoidCallback onPlanDay;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFFAFC7C2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seu dia está em aberto.',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontSize: 23,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Planeje um bloco de tempo ou comece por uma tarefa simples. O resto pode vir depois.',
          style: TextStyle(fontSize: 13, height: 1.5, color: muted),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onPlanDay,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEAF2EF),
                foregroundColor: OrvaColors.primary900,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: const Icon(Icons.schedule_outlined, size: 18),
              label: const Text('Planejar meu dia'),
            ),
            OutlinedButton.icon(
              onPressed: onAddTask,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x44FFFFFF)),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text('Adicionar tarefa'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayMetrics extends StatelessWidget {
  const _DayMetrics({
    required this.overview,
    required this.muted,
    required this.faint,
  });

  final HomeOverview overview;
  final Color muted;
  final Color faint;

  @override
  Widget build(BuildContext context) {
    final coverage = overview.executionCoverage;
    final executedDetail = overview.executionCount == 0
        ? 'nenhum registro hoje'
        : coverage == null
        ? '${overview.executionCount} ${overview.executionCount == 1 ? 'registro' : 'registros'}'
        : '${(coverage * 100).round()}% do planejado';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _HeroMetric(
            label: 'PLANEJADO',
            value: formatMinutes(overview.plannedMinutes),
            detail:
                '${overview.plannedBlockCount} ${overview.plannedBlockCount == 1 ? 'bloco' : 'blocos'} · ${(overview.plannedMinutes / 1440 * 100).round()}% do dia',
            labelColor: muted,
            detailColor: faint,
            valueColor: Colors.white,
          ),
        ),
        Container(
          width: 1,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          color: Colors.white.withValues(alpha: 0.12),
        ),
        Expanded(
          child: _HeroMetric(
            label: 'EXECUTADO',
            value: formatMinutes(overview.executedMinutes),
            detail: executedDetail,
            labelColor: muted,
            detailColor: faint,
            valueColor: const Color(0xFFA8D5C8),
          ),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.labelColor,
    required this.detailColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String detail;
  final Color labelColor;
  final Color detailColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _micro(context, color: labelColor, size: 9.5)),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: orvaMonoStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: valueColor,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, height: 1.3, color: detailColor),
        ),
      ],
    );
  }
}

class _HeroChecklist extends StatelessWidget {
  const _HeroChecklist({required this.digest});

  final ChecklistDigest digest;

  @override
  Widget build(BuildContext context) {
    final ratio = digest.ratio ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${digest.completed} de ${digest.total} tarefas concluídas',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: orvaMonoStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFA8D5C8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1).toDouble(),
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            color: const Color(0xFF9FCFC3),
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, color: color)),
      ],
    );
  }
}

/// 24-hour occupancy strip: planned segments in their category color, real
/// executions as a lighter inner bar, and a terracotta marker for "now".
class _DayRibbon extends StatelessWidget {
  const _DayRibbon({required this.overview});

  final HomeOverview overview;

  @override
  Widget build(BuildContext context) {
    final planned = <({int start, int end, Color color})>[];
    final executed = <({int start, int end})>[];
    for (final item in overview.items) {
      if (item.entry.isExecuted) {
        executed.add((
          start: item.entry.startMinute,
          end: item.entry.endMinute,
        ));
      } else {
        planned.add((
          start: item.entry.startMinute,
          end: item.entry.endMinute,
          color: OrvaCategoryPalette.of(context, item.entry.category),
        ));
      }
    }
    return SizedBox(
      height: 12,
      width: double.infinity,
      child: CustomPaint(
        painter: _DayRibbonPainter(
          planned: planned,
          executed: executed,
          nowMinute: overview.nowMinute,
          trackColor: Colors.white.withValues(alpha: 0.10),
          executionColor: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _DayRibbonPainter extends CustomPainter {
  _DayRibbonPainter({
    required this.planned,
    required this.executed,
    required this.nowMinute,
    required this.trackColor,
    required this.executionColor,
  });

  final List<({int start, int end, Color color})> planned;
  final List<({int start, int end})> executed;
  final int nowMinute;
  final Color trackColor;
  final Color executionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = trackColor);

    canvas.save();
    canvas.clipRRect(track);
    for (final segment in planned) {
      final left = segment.start / 1440 * size.width;
      final width = (segment.end - segment.start) / 1440 * size.width;
      if (width <= 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(left, 0, math.max(width, 1.5), size.height),
        Paint()..color = segment.color.withValues(alpha: 0.9),
      );
    }
    for (final segment in executed) {
      final left = segment.start / 1440 * size.width;
      final width = (segment.end - segment.start) / 1440 * size.width;
      if (width <= 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(left, size.height - 4, math.max(width, 1.5), 4),
        Paint()..color = executionColor,
      );
    }
    final nowX = (nowMinute / 1440 * size.width).clamp(0.0, size.width);
    canvas.drawRect(
      Rect.fromLTWH(nowX - 0.9, -2, 1.8, size.height + 4),
      Paint()..color = OrvaColors.terracotta,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DayRibbonPainter oldDelegate) =>
      oldDelegate.nowMinute != nowMinute ||
      oldDelegate.planned.length != planned.length ||
      oldDelegate.executed.length != executed.length;
}

// ---------------------------------------------------------------------------
// Next activity
// ---------------------------------------------------------------------------

class NextActivityCard extends StatelessWidget {
  const NextActivityCard({
    super.key,
    required this.item,
    required this.nowMinute,
    required this.onOpen,
  });

  /// Null when today's agenda has finished.
  final HomeAgendaItem? item;
  final int nowMinute;
  final ValueChanged<HomeAgendaItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final current = item;
    if (current == null) {
      return const OrvaSurface(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            _SoftIcon(icon: Icons.done_all_rounded),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nada mais previsto para hoje',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'A agenda terminou. Revise o que foi realizado ou planeje o próximo bloco.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final entry = current.entry;
    final color = OrvaCategoryPalette.of(context, entry.category);
    final isLive = current.phase == HomeEntryPhase.live;
    final relative = isLive
        ? 'termina em ${formatMinutes(math.max(1, entry.endMinute - nowMinute))}'
        : 'começa em ${formatMinutes(math.max(1, entry.startMinute - nowMinute))}';
    return OrvaSurface(
      padding: EdgeInsets.zero,
      onTap: () => onOpen(current),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 58,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: OrvaColors.terracotta,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          isLive ? 'ACONTECENDO AGORA' : 'PRÓXIMA ATIVIDADE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _micro(
                            context,
                            color: isLive ? OrvaColors.terracotta : color,
                            size: 9.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relative,
                        style: orvaMonoStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: OrvaColors.tertiaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      height: 1.25,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${formatClock(entry.startMinute)}–${formatClock(entry.endMinute)}',
                        style: orvaMonoStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${entry.category} · ${formatMinutes(entry.durationMinutes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: OrvaColors.tertiaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? OrvaColors.darkSubtle : OrvaColors.subtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: OrvaColors.primary),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions
// ---------------------------------------------------------------------------

enum HomeQuickAction { block, task, execution, habit, calendar }

class HomeQuickActionBar extends StatelessWidget {
  const HomeQuickActionBar({super.key, required this.onAction});

  final ValueChanged<HomeQuickAction> onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? OrvaColors.darkSurface : OrvaColors.surface,
        borderRadius: BorderRadius.circular(OrvaRadius.md),
        border: Border.all(color: _hairline(context)),
      ),
      child: Row(
        children: [
          for (final action in HomeQuickAction.values)
            Expanded(
              child: _QuickActionButton(
                action: action,
                onTap: () => onAction(action),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action, required this.onTap});

  final HomeQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (action) {
      HomeQuickAction.block => (
        Icons.schedule_rounded,
        'Bloco',
        OrvaColors.primary,
      ),
      HomeQuickAction.task => (
        Icons.add_task_rounded,
        'Tarefa',
        OrvaColors.success,
      ),
      HomeQuickAction.execution => (
        Icons.timer_outlined,
        'Registro',
        OrvaColors.information,
      ),
      HomeQuickAction.habit => (
        Icons.repeat_rounded,
        'Hábito',
        OrvaColors.terracotta,
      ),
      HomeQuickAction.calendar => (
        Icons.calendar_month_outlined,
        'Agenda',
        OrvaColors.secondaryText,
      ),
    };
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OrvaRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: OrvaColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _micro(context, size: 10.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(right: 6),
            color: _hairline(context),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

class DayTimelinePreview extends StatelessWidget {
  const DayTimelinePreview({
    super.key,
    required this.slots,
    required this.nowMinute,
    required this.onOpenCalendar,
    required this.onOpenEntry,
    required this.onPlan,
  });

  final List<HomeTimelineSlot> slots;
  final int nowMinute;
  final VoidCallback onOpenCalendar;
  final ValueChanged<HomeAgendaItem> onOpenEntry;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final upcoming = slots.indexWhere((slot) => slot.endMinute > nowMinute);
    final start = upcoming == -1
        ? math.max(0, slots.length - 4)
        : math.max(0, upcoming - 1);
    final visible = slots.skip(start).take(6).toList();
    final hidden = slots.length - start - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Agenda de hoje',
          actionLabel: 'Calendário',
          onAction: onOpenCalendar,
        ),
        const SizedBox(height: 10),
        OrvaSurface(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: slots.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Row(
                    children: [
                      const _SoftIcon(icon: Icons.event_available_outlined),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Nenhum horário planejado para hoje.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                      TextButton(onPressed: onPlan, child: const Text('Criar')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildRows(context, visible),
                    if (hidden > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 8, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onOpenCalendar,
                            child: Text(
                              '+$hidden ${hidden == 1 ? 'item' : 'itens'} na agenda',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _buildRows(
    BuildContext context,
    List<HomeTimelineSlot> visible,
  ) {
    final rows = <Widget>[];
    var nowInserted = false;
    for (var index = 0; index < visible.length; index++) {
      final slot = visible[index];
      if (!nowInserted && slot.startMinute >= nowMinute) {
        rows.add(_NowMarker(nowMinute: nowMinute));
        nowInserted = true;
      }
      final widget = switch (slot) {
        HomeEntrySlot(:final item) => _TimelineRow(
          item: item,
          onTap: () => onOpenEntry(item),
        ),
        HomeGapSlot() => _GapRow(slot: slot),
      };
      rows.add(widget);
      if (index < visible.length - 1) {
        rows.add(
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: _hairline(context).withValues(alpha: 0.7),
          ),
        );
      }
    }
    return rows;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.onTap});

  final HomeAgendaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final isPast = item.phase == HomeEntryPhase.past;
    final isLive = item.phase == HomeEntryPhase.live;
    final color = OrvaCategoryPalette.of(context, entry.category);
    final subtitle = switch (item.phase) {
      HomeEntryPhase.realized =>
        'realizado · ${formatMinutes(entry.durationMinutes)}',
      HomeEntryPhase.live =>
        '${entry.category} · até ${formatClock(entry.endMinute)}',
      HomeEntryPhase.past => '${entry.category} · sem registro',
      HomeEntryPhase.upcoming =>
        '${entry.category} · ${formatMinutes(entry.durationMinutes)}',
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 14, 9),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                formatClock(entry.startMinute),
                style: orvaMonoStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPast
                      ? OrvaColors.tertiaryText
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 11),
              decoration: BoxDecoration(
                color: entry.isExecuted || isLive ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: entry.isExecuted || isLive
                    ? null
                    : Border.all(
                        color: (isPast ? OrvaColors.tertiaryText : color)
                            .withValues(alpha: isPast ? 0.5 : 0.9),
                        width: 1.5,
                      ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
                      color: isPast ? OrvaColors.tertiaryText : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: isPast ? OrvaColors.tertiaryText : null,
                    ),
                  ),
                ],
              ),
            ),
            if (isLive)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'agora',
                  style: _micro(context, color: OrvaColors.terracotta, size: 9),
                ),
              )
            else if (item.phase == HomeEntryPhase.realized)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'real',
                  style: _micro(
                    context,
                    color: OrvaColors.information,
                    size: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.slot});

  final HomeGapSlot slot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 14, 9),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              formatClock(slot.startMinute),
              style: orvaMonoStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: OrvaColors.tertiaryText,
              ),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: OrvaColors.tertiaryText.withValues(alpha: 0.45),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Tempo livre · ${formatMinutes(slot.minutes)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: OrvaColors.tertiaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowMarker extends StatelessWidget {
  const _NowMarker({required this.nowMinute});

  final int nowMinute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 14, 6),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              formatClock(nowMinute),
              style: orvaMonoStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: OrvaColors.terracotta,
              ),
            ),
          ),
          Expanded(child: Container(height: 1.4, color: OrvaColors.terracotta)),
          const SizedBox(width: 8),
          Text(
            'AGORA',
            style: _micro(context, color: OrvaColors.terracotta, size: 8.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Priorities
// ---------------------------------------------------------------------------

class PrioritiesCard extends StatelessWidget {
  const PrioritiesCard({
    super.key,
    required this.items,
    required this.obligations,
    required this.onToggleItem,
    required this.onOpenChecklists,
    required this.onOpenObligations,
  });

  final List<Map<String, Object?>> items;
  final List<CalendarEntry> obligations;
  final ValueChanged<Map<String, Object?>> onToggleItem;
  final VoidCallback onOpenChecklists;
  final VoidCallback onOpenObligations;

  @override
  Widget build(BuildContext context) {
    final openItems = items
        .where((item) => intValue(item['completed']) == 0)
        .take(4)
        .toList();
    if (openItems.isEmpty && obligations.isEmpty && items.isEmpty) {
      return const SizedBox.shrink();
    }

    final pendingObligations = obligations.take(3).toList();
    final totalOpen = items
        .where((item) => intValue(item['completed']) == 0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Pendências',
          actionLabel: 'Checklists',
          onAction: onOpenChecklists,
        ),
        const SizedBox(height: 10),
        OrvaSurface(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              if (openItems.isEmpty && pendingObligations.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.task_alt_rounded,
                        size: 19,
                        color: OrvaColors.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nada pendente agora. O que foi planejado está concluído.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              for (var index = 0; index < openItems.length; index++) ...[
                _ChecklistPriorityRow(
                  item: openItems[index],
                  onToggle: () => onToggleItem(openItems[index]),
                ),
                if (index < openItems.length - 1)
                  Divider(
                    height: 1,
                    indent: 48,
                    endIndent: 14,
                    color: _hairline(context).withValues(alpha: 0.7),
                  ),
              ],
              if (openItems.isNotEmpty && pendingObligations.isNotEmpty)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: _hairline(context).withValues(alpha: 0.7),
                ),
              for (
                var index = 0;
                index < pendingObligations.length;
                index++
              ) ...[
                _ObligationRow(
                  entry: pendingObligations[index],
                  onTap: onOpenObligations,
                ),
                if (index < pendingObligations.length - 1)
                  Divider(
                    height: 1,
                    indent: 48,
                    endIndent: 14,
                    color: _hairline(context).withValues(alpha: 0.7),
                  ),
              ],
              if (totalOpen > openItems.length)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+${totalOpen - openItems.length} outras tarefas em aberto',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 11.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistPriorityRow extends StatelessWidget {
  const _ChecklistPriorityRow({required this.item, required this.onToggle});

  final Map<String, Object?> item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 12, 2),
      child: Row(
        children: [
          Checkbox(
            value: false,
            onChanged: (_) => onToggle(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: OrvaColors.borderStrong),
            ),
            side: const BorderSide(color: OrvaColors.borderStrong, width: 1.4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['title_snapshot'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['checklist_title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObligationRow extends StatelessWidget {
  const _ObligationRow({required this.entry, required this.onTap});

  final CalendarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
        child: Row(
          children: [
            const Icon(
              Icons.event_repeat_rounded,
              size: 17,
              color: Color(0xFF8B6B9E),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Obrigação · ${formatClock(entry.startMinute)}–${formatClock(entry.endMinute)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: OrvaColors.tertiaryText,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Habits, goals, study
// ---------------------------------------------------------------------------

class HabitConsistencyCard extends StatelessWidget {
  const HabitConsistencyCard({
    super.key,
    required this.report,
    required this.onOpen,
  });

  final HabitReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) return const SizedBox.shrink();
    final consistency = report.consistency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Consistência',
          actionLabel: 'Hábitos',
          onAction: onOpen,
        ),
        const SizedBox(height: 10),
        OrvaSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (consistency != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(consistency * 100).round()}%',
                      style: orvaMonoStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: OrvaColors.primary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${report.loggedDays} de ${report.eligibleDays} oportunidades nesta semana',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 11.5, height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Nenhum dia elegível nesta semana para os hábitos ativos.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 12),
                  ),
                ),
              for (var index = 0; index < report.signals.length; index++) ...[
                _HabitRow(signal: report.signals[index]),
                if (index < report.signals.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Divider(height: 1, color: _hairline(context)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.signal});

  final HabitSignal signal;

  @override
  Widget build(BuildContext context) {
    final habit = signal.habit;
    final quantity = _formatQuantity(signal.todayQuantity);
    final target = habit.target;
    final todayLabel = !signal.isTodayEligible
        ? 'Fora dos dias ativos hoje'
        : target != null && target > 0
        ? '$quantity de ${_formatQuantity(target)} ${habit.unit} hoje'
        : signal.todayQuantity > 0
        ? '$quantity ${habit.unit} hoje'
        : 'Ainda sem registro hoje';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                todayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: signal.isTodayLogged
                      ? OrvaColors.success
                      : OrvaColors.tertiaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _WeekDots(days: signal.days),
      ],
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.days});

  final List<HabitDaySignal> days;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = (isDark ? OrvaColors.darkBorder : OrvaColors.borderStrong)
        .withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final day in days)
          Semantics(
            label:
                '${day.date.day}/${day.date.month}: '
                '${!day.eligible
                    ? 'sem oportunidade'
                    : day.logged
                    ? 'registrado'
                    : 'sem registro'}',
            child: Container(
              width: day.isToday ? 10 : 8,
              height: day.isToday ? 10 : 8,
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: day.eligible && day.logged
                    ? OrvaColors.success
                    : Colors.transparent,
                border: Border.all(
                  color: day.isToday
                      ? OrvaColors.primary
                      : day.eligible
                      ? OrvaColors.primary.withValues(alpha: 0.35)
                      : inactive,
                  width: day.isToday ? 1.6 : 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

class GoalsCard extends StatelessWidget {
  const GoalsCard({
    super.key,
    required this.goals,
    required this.onOpen,
    required this.onCreate,
  });

  final List<Map<String, Object?>> goals;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Metas ativas',
          actionLabel: goals.isEmpty ? null : 'Ver metas',
          onAction: goals.isEmpty ? null : onOpen,
        ),
        const SizedBox(height: 10),
        OrvaSurface(
          child: goals.isEmpty
              ? Row(
                  children: [
                    const _SoftIcon(icon: Icons.flag_outlined),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Nenhuma meta ativa. Defina o que quer construir, no seu ritmo.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                    TextButton(onPressed: onCreate, child: const Text('Criar')),
                  ],
                )
              : Column(
                  children: [
                    for (var index = 0; index < goals.length; index++) ...[
                      _GoalRow(goal: goals[index]),
                      if (index < goals.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: _hairline(context)),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final Map<String, Object?> goal;

  @override
  Widget build(BuildContext context) {
    final progress = (doubleValue(goal['progress_value']) / 100).clamp(0, 1);
    final category = (goal['category'] as String?)?.trim();
    final deadline = (goal['deadline'] as String?)?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${goal['title'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(progress * 100).round()}%',
              style: orvaMonoStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OrvaColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: _hairline(context),
            color: OrvaColors.primary,
          ),
        ),
        if ((category != null && category.isNotEmpty) ||
            (deadline != null && deadline.isNotEmpty)) ...[
          const SizedBox(height: 5),
          Text(
            [
              if (category != null && category.isNotEmpty) category,
              if (deadline != null && deadline.isNotEmpty) 'prazo $deadline',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class StudyEvidenceCard extends StatelessWidget {
  const StudyEvidenceCard({
    super.key,
    required this.study,
    required this.onOpen,
  });

  final StudyDigest study;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (!study.hasEvidence) return const SizedBox.shrink();
    return OrvaSurface(
      onTap: onOpen,
      child: Row(
        children: [
          const _SoftIcon(icon: Icons.menu_book_outlined),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estudo nesta semana',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMinutes(study.minutes)} em ${study.sessions} '
                  '${study.sessions == 1 ? 'sessão' : 'sessões'}'
                  '${study.reviews > 0 ? ' · ${study.reviews} ${study.reviews == 1 ? 'revisão' : 'revisões'}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: OrvaColors.tertiaryText,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reflection and states
// ---------------------------------------------------------------------------

class HomeReflectionCard extends StatelessWidget {
  const HomeReflectionCard({
    super.key,
    required this.quote,
    required this.author,
  });

  final String quote;
  final String author;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? OrvaColors.darkSubtle : OrvaColors.subtle,
        borderRadius: BorderRadius.circular(OrvaRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REFLEXÃO DO DIA', style: _micro(context, size: 9.5)),
          const SizedBox(height: 8),
          Text(
            '“$quote”',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 15,
              height: 1.45,
              fontStyle: FontStyle.italic,
              fontFamily: 'Fraunces',
              fontFamilyFallback: const ['Georgia', 'serif'],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '— $author',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 11.5, color: OrvaColors.tertiaryText),
          ),
        ],
      ),
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final block = _hairline(context).withValues(alpha: 0.6);
    Widget bar(double height, {double? width, double radius = 12}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: block,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            bar(34, width: 34, radius: 11),
            const SizedBox(width: 10),
            bar(18, width: 54),
            const Spacer(),
            bar(24, width: 24, radius: 8),
            const SizedBox(width: 12),
            bar(24, width: 24, radius: 8),
          ],
        ),
        const SizedBox(height: 30),
        bar(11, width: 120, radius: 6),
        const SizedBox(height: 14),
        bar(34, width: 240, radius: 8),
        const SizedBox(height: 24),
        bar(248, radius: 20),
        const SizedBox(height: 16),
        bar(64, radius: 14),
        const SizedBox(height: 16),
        bar(240, radius: 16),
      ],
    );
  }
}

/// A quiet placeholder used when a section has no records yet.
class HomeQuietState extends StatelessWidget {
  const HomeQuietState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return OrvaSurface(
      child: Row(
        children: [
          _SoftIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 12.5, height: 1.45),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
