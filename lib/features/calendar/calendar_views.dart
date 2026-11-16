import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/domain/calendar_layout.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/theme/orva_tokens.dart';
import '../../core/widgets/orva_widgets.dart';

const double _weekHourHeight = 44;
const double _weekGutter = 44;

/// Week view. On wide screens it is a seven-column time grid; on phones it
/// becomes seven readable day rows with a proportional activity strip instead
/// of squeezing seven illegible columns.
class WeekBoard extends StatelessWidget {
  const WeekBoard({
    super.key,
    required this.byDay,
    required this.days,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onOpenDay,
  });

  final Map<String, List<CalendarEntry>> byDay;
  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 860) {
        return _CompactWeek(byDay: byDay, days: days, onOpenDay: onOpenDay);
      }
      return _WideWeek(
        byDay: byDay,
        days: days,
        selectedDay: selectedDay,
        onSelectDay: onSelectDay,
        onOpenDay: onOpenDay,
      );
    },
  );
}

class _CompactWeek extends StatelessWidget {
  const _CompactWeek({
    required this.byDay,
    required this.days,
    required this.onOpenDay,
  });

  final Map<String, List<CalendarEntry>> byDay;
  final List<DateTime> days;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        OrvaSpace.md,
        OrvaSpace.xs,
        OrvaSpace.md,
        96,
      ),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(height: OrvaSpace.xs),
      itemBuilder: (context, index) {
        final day = days[index];
        final entries = byDay[localDateKey(day)] ?? const <CalendarEntry>[];
        final summary = DaySummary.of(entries);
        final isToday = isSameLocalDay(day, now);
        return Semantics(
          button: true,
          label:
              '${DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(day)}. ${summary.entries} atividades, ${formatMinutes(summary.planned)} planejados.',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(OrvaRadius.md),
              onTap: () => onOpenDay(day),
              child: Container(
                padding: const EdgeInsets.all(OrvaSpace.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(OrvaRadius.md),
                  border: Border.all(
                    color: isToday
                        ? OrvaColors.primary500
                        : (Theme.of(context).brightness == Brightness.dark
                              ? OrvaColors.darkBorder
                              : OrvaColors.border),
                  ),
                  color: isToday
                      ? OrvaColors.primary.withValues(alpha: 0.06)
                      : (Theme.of(context).brightness == Brightness.dark
                            ? OrvaColors.darkSurface
                            : OrvaColors.surface),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat(
                                  'EEE',
                                  'pt_BR',
                                ).format(day).replaceAll('.', ''),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isToday
                                          ? OrvaColors.primary
                                          : null,
                                    ),
                              ),
                              Text(
                                day.day.toString().padLeft(2, '0'),
                                style: orvaMonoStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isToday ? OrvaColors.primary : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _MiniDayStrip(entries: entries)),
                        const SizedBox(width: OrvaSpace.xs),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              summary.entries == 0
                                  ? 'livre'
                                  : formatMinutes(summary.planned),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (summary.conflicts > 0)
                              Text(
                                '${summary.conflicts} conflito${summary.conflicts > 1 ? 's' : ''}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: OrvaColors.mustard,
                                      fontSize: 11,
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniDayStrip extends StatelessWidget {
  const _MiniDayStrip({required this.entries});

  final List<CalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).brightness == Brightness.dark
        ? OrvaColors.darkBorder
        : OrvaColors.border;
    final positioned = layoutDayLanes(entries);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 26,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: border.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              for (final item in positioned)
                Positioned(
                  left: width * item.entry.startMinute / 1440,
                  width: math.max(
                    width * item.entry.durationMinutes / 1440,
                    3.0,
                  ),
                  top: 4 + math.min(item.lane, 1) * 9,
                  height: 7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: item.entry.isExecuted
                          ? Colors.transparent
                          : OrvaCategoryPalette.of(
                              context,
                              item.entry.category,
                            ),
                      border: item.entry.isExecuted
                          ? Border.all(
                              color: OrvaCategoryPalette.of(
                                context,
                                item.entry.category,
                              ),
                              width: 1,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WideWeek extends StatefulWidget {
  const _WideWeek({
    required this.byDay,
    required this.days,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onOpenDay,
  });

  final Map<String, List<CalendarEntry>> byDay;
  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<_WideWeek> createState() => _WideWeekState();
}

class _WideWeekState extends State<_WideWeek> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final now = DateTime.now();
      final inWeek = widget.days.any((day) => isSameLocalDay(day, now));
      final target =
          (inWeek ? now.hour * 60 + now.minute - 120 : 7 * 60) /
          60 *
          _weekHourHeight;
      _controller.jumpTo(
        target.clamp(0, _controller.position.maxScrollExtent).toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: OrvaSpace.md),
          child: Row(
            children: [
              const SizedBox(width: _weekGutter + OrvaSpace.md),
              for (final day in widget.days)
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onOpenDay(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSameLocalDay(day, now)
                                ? OrvaColors.primary
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? OrvaColors.darkBorder
                                      : OrvaColors.border),
                            width: isSameLocalDay(day, now) ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat(
                              'EEE',
                              'pt_BR',
                            ).format(day).replaceAll('.', ''),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isSameLocalDay(day, now)
                                      ? OrvaColors.primary
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${day.day}',
                            style: orvaMonoStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSameLocalDay(day, now)
                                  ? OrvaColors.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _controller,
            padding: const EdgeInsets.only(bottom: OrvaSpace.lg),
            child: SizedBox(
              height: 24 * _weekHourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _weekGutter,
                    child: Stack(
                      children: [
                        for (var hour = 1; hour < 24; hour++)
                          Positioned(
                            top: hour * _weekHourHeight - 7,
                            right: 8,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}h',
                              style: orvaMonoStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: OrvaColors.tertiaryText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final day in widget.days)
                    Expanded(
                      child: _WeekDayColumn(
                        entries:
                            widget.byDay[localDateKey(day)] ??
                            const <CalendarEntry>[],
                        isToday: isSameLocalDay(day, now),
                        selected: isSameLocalDay(day, widget.selectedDay),
                        onTap: () {
                          widget.onSelectDay(day);
                          widget.onOpenDay(day);
                        },
                      ),
                    ),
                  const SizedBox(width: OrvaSpace.md),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.entries,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final List<CalendarEntry> entries;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? OrvaColors.darkBorder : OrvaColors.border;
    final positioned = layoutDayLanes(entries);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Container(
            decoration: BoxDecoration(
              color: isToday
                  ? OrvaColors.primary.withValues(alpha: 0.04)
                  : (selected
                        ? OrvaColors.primary.withValues(alpha: 0.02)
                        : null),
              border: Border(
                left: BorderSide(color: line.withValues(alpha: 0.7)),
              ),
            ),
            child: Stack(
              children: [
                for (var hour = 1; hour < 24; hour++)
                  Positioned(
                    top: hour * _weekHourHeight,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: line.withValues(alpha: 0.5),
                    ),
                  ),
                for (final item in positioned)
                  Positioned(
                    top: item.entry.startMinute / 60 * _weekHourHeight,
                    height: math.max(
                      item.entry.durationMinutes / 60 * _weekHourHeight - 2,
                      16.0,
                    ),
                    left: width * item.lane / item.laneCount + 2,
                    width: width / item.laneCount - 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.entry.isExecuted
                              ? Colors.transparent
                              : OrvaCategoryPalette.soft(
                                  context,
                                  OrvaCategoryPalette.of(
                                    context,
                                    item.entry.category,
                                  ),
                                ),
                          border: Border(
                            left: BorderSide(
                              color: OrvaCategoryPalette.of(
                                context,
                                item.entry.category,
                              ),
                              width: item.entry.isExecuted ? 1 : 3,
                            ),
                          ),
                        ),
                        child: Text(
                          item.entry.title,
                          maxLines: item.entry.durationMinutes >= 45 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Month grid with discreet activity indicators. Tapping a day selects it; the
/// host shows that day's summary and can open the detailed timeline.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.counts,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Map<String, int> counts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final days = monthGridDays(month);
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? OrvaColors.darkBorder : OrvaColors.border;
    const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return Column(
      children: [
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: _MonthCell(
                    day: days[week * 7 + index],
                    month: month,
                    isToday: isSameLocalDay(days[week * 7 + index], now),
                    isSelected: isSameLocalDay(
                      days[week * 7 + index],
                      selectedDay,
                    ),
                    count: counts[localDateKey(days[week * 7 + index])] ?? 0,
                    border: line,
                    onTap: () => onSelect(days[week * 7 + index]),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.month,
    required this.isToday,
    required this.isSelected,
    required this.count,
    required this.border,
    required this.onTap,
  });

  final DateTime day;
  final DateTime month;
  final bool isToday;
  final bool isSelected;
  final int count;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inMonth = day.month == month.month;
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${day.day} de ${DateFormat('MMMM', 'pt_BR').format(day)}${isToday ? ', hoje' : ''}. $count ${count == 1 ? 'atividade' : 'atividades'}.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OrvaRadius.xs),
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OrvaRadius.xs),
            color: isSelected
                ? OrvaColors.primary.withValues(alpha: 0.10)
                : null,
            border: Border.all(
              color: isSelected
                  ? OrvaColors.primary
                  : (isToday ? OrvaColors.primary300 : Colors.transparent),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${day.day}',
                style: orvaMonoStyle(
                  fontSize: 12,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: !inMonth
                      ? OrvaColors.tertiaryText.withValues(alpha: 0.6)
                      : (isToday ? OrvaColors.primary : null),
                ),
              ),
              const SizedBox(height: 3),
              if (count > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < math.min(count, 3); i++)
                      Container(
                        width: 3.5,
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: OrvaColors.primary.withValues(
                            alpha: inMonth ? 0.55 : 0.25,
                          ),
                        ),
                      ),
                    if (count > 3)
                      Text(
                        '+',
                        style: TextStyle(
                          fontSize: 8,
                          height: 1,
                          color: OrvaColors.primary.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
