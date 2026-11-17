package com.appguilherme.orva.widgets

import android.content.Context
import android.widget.RemoteViews
import com.appguilherme.orva.R

/** Next activity, checklist pulse and planned time. */
class TodayWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_today
    override val route = "today"
    override val darkSurface = true

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val today = snapshot.today
        views.text(R.id.widget_today_date, snapshot.dateLabel.uppercase())
        views.text(R.id.widget_today_phase, today.phaseLabel.uppercase())
        views.text(R.id.widget_today_headline, today.headline)
        views.text(R.id.widget_today_time, today.timeLabel)
        views.text(R.id.widget_today_detail, today.detail)
        views.text(R.id.widget_today_checklist, today.checklistLabel)
        views.text(
            R.id.widget_today_planned,
            "Planejado hoje · ${snapshot.progress.plannedLabel}",
        )
        views.visible(R.id.widget_today_time, today.timeLabel.isNotBlank())
        views.visible(R.id.widget_today_detail, today.detail.isNotBlank())
    }
}

/** Pending checklist items for today. */
class TasksWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_tasks
    override val route = "tasks"
    override val darkSurface = false

    private val rows = intArrayOf(
        R.id.widget_task_row_1,
        R.id.widget_task_row_2,
        R.id.widget_task_row_3,
        R.id.widget_task_row_4,
    )
    private val titles = intArrayOf(
        R.id.widget_task_title_1,
        R.id.widget_task_title_2,
        R.id.widget_task_title_3,
        R.id.widget_task_title_4,
    )
    private val sources = intArrayOf(
        R.id.widget_task_source_1,
        R.id.widget_task_source_2,
        R.id.widget_task_source_3,
        R.id.widget_task_source_4,
    )

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val tasks = snapshot.tasks
        views.text(
            R.id.widget_tasks_summary,
            if (tasks.total == 0) {
                "Nenhuma tarefa para hoje"
            } else {
                "${tasks.completed} de ${tasks.total} concluídas"
            },
        )
        for (index in rows.indices) {
            val task = tasks.items.getOrNull(index)
            views.visible(rows[index], task != null)
            if (task != null) {
                views.text(titles[index], task.title)
                views.text(sources[index], task.source)
                views.visible(sources[index], task.source.isNotBlank())
            }
        }
        val empty = tasks.items.isEmpty()
        views.visible(R.id.widget_tasks_empty, empty)
        if (empty) {
            views.text(
                R.id.widget_tasks_empty,
                if (tasks.total > 0 && tasks.completed == tasks.total) {
                    "Tudo concluído por hoje."
                } else {
                    "Nada pendente agora."
                },
            )
        }
    }
}

/** Planned vs executed time and checklist completion. */
class ProgressWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_progress
    override val route = "progress"
    override val darkSurface = false

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val progress = snapshot.progress
        views.text(
            R.id.widget_progress_coverage,
            progress.coveragePercent?.let { "$it%" } ?: "—",
        )
        views.progress(R.id.widget_progress_bar, progress.coveragePercent)
        views.text(R.id.widget_progress_planned, progress.plannedLabel)
        views.text(R.id.widget_progress_executed, progress.executedLabel)
        views.text(
            R.id.widget_progress_checklist,
            progress.checklistPercent?.let { "$it%" } ?: "—",
        )
        views.text(R.id.widget_progress_free, progress.freeLabel)
        views.text(R.id.widget_progress_conflicts, progress.conflictLabel)
        views.visible(R.id.widget_progress_conflicts, progress.conflictLabel.isNotBlank())
    }
}

/** Fixed Beto/Alfredo pair with weighted, evidence-only shares. */
class ComparisonWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_comparison
    override val route = "comparison"
    override val darkSurface = false

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val comparison = snapshot.comparison
        views.text(R.id.widget_comparison_status, comparison.statusLabel)
        views.text(R.id.widget_comparison_alfredo_name, comparison.alfredoName)
        views.text(
            R.id.widget_comparison_alfredo_pct,
            comparison.alfredoPercent?.let { "$it%" } ?: "—",
        )
        views.progress(
            R.id.widget_comparison_alfredo_bar,
            comparison.alfredoPercent,
        )
        views.text(R.id.widget_comparison_beto_name, comparison.betoName)
        views.text(
            R.id.widget_comparison_beto_pct,
            comparison.betoPercent?.let { "$it%" } ?: "—",
        )
        views.progress(R.id.widget_comparison_beto_bar, comparison.betoPercent)
        views.text(R.id.widget_comparison_evidence, comparison.evidenceLabel)
    }
}

/** Active goals with their real progress. */
class GoalsWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_goals
    override val route = "goals"
    override val darkSurface = false

    private val rows = intArrayOf(
        R.id.widget_goal_row_1,
        R.id.widget_goal_row_2,
        R.id.widget_goal_row_3,
    )
    private val titles = intArrayOf(
        R.id.widget_goal_title_1,
        R.id.widget_goal_title_2,
        R.id.widget_goal_title_3,
    )
    private val percents = intArrayOf(
        R.id.widget_goal_pct_1,
        R.id.widget_goal_pct_2,
        R.id.widget_goal_pct_3,
    )
    private val bars = intArrayOf(
        R.id.widget_goal_bar_1,
        R.id.widget_goal_bar_2,
        R.id.widget_goal_bar_3,
    )

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val goals = snapshot.goals
        views.text(R.id.widget_goals_summary, goals.summary)
        for (index in rows.indices) {
            val goal = goals.items.getOrNull(index)
            views.visible(rows[index], goal != null)
            if (goal != null) {
                views.text(titles[index], goal.title)
                views.text(percents[index], "${goal.percent}%")
                views.progress(bars[index], goal.percent)
            }
        }
        val empty = goals.items.isEmpty()
        views.visible(R.id.widget_goals_empty, empty)
        if (empty) views.text(R.id.widget_goals_empty, "Crie uma meta para acompanhar aqui.")
    }
}

/** Seven-day habit consistency with today's status. */
class HabitsWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_habits
    override val route = "habits"
    override val darkSurface = false

    private val rows = intArrayOf(
        R.id.widget_habit_row_1,
        R.id.widget_habit_row_2,
        R.id.widget_habit_row_3,
        R.id.widget_habit_row_4,
    )
    private val names = intArrayOf(
        R.id.widget_habit_name_1,
        R.id.widget_habit_name_2,
        R.id.widget_habit_name_3,
        R.id.widget_habit_name_4,
    )
    private val statuses = intArrayOf(
        R.id.widget_habit_today_1,
        R.id.widget_habit_today_2,
        R.id.widget_habit_today_3,
        R.id.widget_habit_today_4,
    )
    private val percents = intArrayOf(
        R.id.widget_habit_pct_1,
        R.id.widget_habit_pct_2,
        R.id.widget_habit_pct_3,
        R.id.widget_habit_pct_4,
    )

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val habits = snapshot.habits
        views.text(R.id.widget_habits_percent, habits.percent?.let { "$it%" } ?: "—")
        views.text(R.id.widget_habits_summary, habits.summary)
        for (index in rows.indices) {
            val habit = habits.items.getOrNull(index)
            views.visible(rows[index], habit != null)
            if (habit != null) {
                views.text(names[index], habit.name)
                views.text(statuses[index], habit.todayLabel)
                views.text(
                    percents[index],
                    habit.consistencyPercent?.let { "$it%" } ?: "—",
                )
            }
        }
    }
}

/** Weekly study evidence. */
class StudyWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_study
    override val route = "study"
    override val darkSurface = false

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val study = snapshot.study
        views.text(R.id.widget_study_minutes, study.minutesLabel)
        views.text(R.id.widget_study_sessions, study.sessionsLabel)
        views.text(R.id.widget_study_reviews, study.reviewsLabel)
        views.text(R.id.widget_study_days, study.daysLabel)
        views.text(R.id.widget_study_summary, study.summary)
    }
}

/** Next planned blocks for today. */
class AgendaWidgetProvider : OrvaWidgetProvider() {
    override val layoutRes = R.layout.orva_widget_agenda
    override val route = "agenda"
    override val darkSurface = true

    private val rows = intArrayOf(
        R.id.widget_agenda_row_1,
        R.id.widget_agenda_row_2,
        R.id.widget_agenda_row_3,
    )
    private val times = intArrayOf(
        R.id.widget_agenda_time_1,
        R.id.widget_agenda_time_2,
        R.id.widget_agenda_time_3,
    )
    private val titles = intArrayOf(
        R.id.widget_agenda_title_1,
        R.id.widget_agenda_title_2,
        R.id.widget_agenda_title_3,
    )
    private val subtitles = intArrayOf(
        R.id.widget_agenda_subtitle_1,
        R.id.widget_agenda_subtitle_2,
        R.id.widget_agenda_subtitle_3,
    )

    override fun bind(context: Context, views: RemoteViews, snapshot: WidgetSnapshot) {
        val agenda = snapshot.agenda
        views.text(R.id.widget_agenda_summary, agenda.summary)
        for (index in rows.indices) {
            val item = agenda.items.getOrNull(index)
            views.visible(rows[index], item != null)
            if (item != null) {
                views.text(times[index], item.timeLabel)
                views.text(titles[index], item.title)
                views.text(subtitles[index], item.subtitle)
            }
        }
        val empty = agenda.items.isEmpty()
        views.visible(R.id.widget_agenda_empty, empty)
        if (empty) {
            views.text(R.id.widget_agenda_empty, agenda.summary)
        }
    }
}
