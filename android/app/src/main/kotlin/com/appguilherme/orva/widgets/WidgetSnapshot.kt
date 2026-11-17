package com.appguilherme.orva.widgets

import org.json.JSONArray
import org.json.JSONObject

/**
 * Native view of the sanitized snapshot produced by Flutter.
 *
 * This class only reads the transport format; it never queries SQLite and never
 * computes progress. Unknown or malformed values fall back to safe defaults so a
 * corrupt snapshot cannot crash a launcher.
 */
data class WidgetSnapshot(
    val schemaVersion: Int,
    val generatedAtMillis: Long,
    val dateLabel: String,
    val locked: Boolean,
    val today: Today,
    val progress: Progress,
    val tasks: TaskList,
    val comparison: Comparison,
    val goals: GoalList,
    val habits: HabitList,
    val study: Study,
    val agenda: AgendaList,
) {
    data class Today(
        val phaseLabel: String,
        val headline: String,
        val detail: String,
        val timeLabel: String,
        val checklistLabel: String,
    )

    data class Progress(
        val plannedLabel: String,
        val executedLabel: String,
        val coveragePercent: Int?,
        val checklistPercent: Int?,
        val freeLabel: String,
        val conflictLabel: String,
    )

    data class Task(val title: String, val source: String)

    data class TaskList(val completed: Int, val total: Int, val items: List<Task>)

    data class Comparison(
        val alfredoName: String,
        val betoName: String,
        val alfredoPercent: Int?,
        val betoPercent: Int?,
        val statusLabel: String,
        val evidenceLabel: String,
    )

    data class Goal(val title: String, val percent: Int, val deadlineLabel: String)

    data class GoalList(val summary: String, val items: List<Goal>)

    data class Habit(
        val name: String,
        val todayLabel: String,
        val consistencyPercent: Int?,
    )

    data class HabitList(
        val summary: String,
        val percent: Int?,
        val items: List<Habit>,
    )

    data class Study(
        val minutesLabel: String,
        val sessionsLabel: String,
        val reviewsLabel: String,
        val daysLabel: String,
        val summary: String,
    )

    data class AgendaItem(
        val timeLabel: String,
        val title: String,
        val subtitle: String,
        val isLive: Boolean,
    )

    data class AgendaList(val summary: String, val items: List<AgendaItem>)

    companion object {
        const val CURRENT_SCHEMA_VERSION = 1

        /** Returns null when the payload is absent, truncated or from a newer schema. */
        fun parse(raw: String?): WidgetSnapshot? {
            if (raw.isNullOrBlank() || raw.length > 64_000) return null
            return try {
                val json = JSONObject(raw)
                if (json.optInt("schemaVersion", -1) != CURRENT_SCHEMA_VERSION) {
                    return null
                }
                WidgetSnapshot(
                    schemaVersion = CURRENT_SCHEMA_VERSION,
                    generatedAtMillis = json.optLong("generatedAtMillis", 0L),
                    dateLabel = json.optString("dateLabel"),
                    locked = json.optBoolean("locked", false),
                    today = json.optJSONObject("today")?.toToday() ?: emptyToday(),
                    progress = json.optJSONObject("progress")?.toProgress() ?: emptyProgress(),
                    tasks = json.optJSONObject("tasks")?.toTaskList() ?: TaskList(0, 0, emptyList()),
                    comparison = json.optJSONObject("comparison")?.toComparison()
                        ?: Comparison("Alfredo", "Beto", null, null, "Sem comparação", ""),
                    goals = json.optJSONObject("goals")?.toGoalList() ?: GoalList("", emptyList()),
                    habits = json.optJSONObject("habits")?.toHabitList() ?: HabitList("", null, emptyList()),
                    study = json.optJSONObject("study")?.toStudy() ?: emptyStudy(),
                    agenda = json.optJSONObject("agenda")?.toAgendaList() ?: AgendaList("", emptyList()),
                )
            } catch (_: Exception) {
                null
            }
        }

        private fun emptyToday() = Today("Hoje", "Abra o Orva", "", "", "")

        private fun emptyProgress() = Progress("—", "—", null, null, "", "")

        private fun emptyStudy() = Study("0min", "0 sessões", "0 revisões", "0 dias", "")

        private fun JSONObject.toToday() = Today(
            phaseLabel = optString("phaseLabel"),
            headline = optString("headline"),
            detail = optString("detail"),
            timeLabel = optString("timeLabel"),
            checklistLabel = optString("checklistLabel"),
        )

        private fun JSONObject.toProgress() = Progress(
            plannedLabel = optString("plannedLabel", "—"),
            executedLabel = optString("executedLabel", "—"),
            coveragePercent = optNullableInt("coveragePercent"),
            checklistPercent = optNullableInt("checklistPercent"),
            freeLabel = optString("freeLabel"),
            conflictLabel = optString("conflictLabel"),
        )

        private fun JSONObject.toTaskList() = TaskList(
            completed = optInt("completed", 0),
            total = optInt("total", 0),
            items = optJSONArray("items").mapObjects {
                Task(it.optString("title"), it.optString("source"))
            },
        )

        private fun JSONObject.toComparison() = Comparison(
            alfredoName = optString("alfredoName", "Alfredo"),
            betoName = optString("betoName", "Beto"),
            alfredoPercent = optNullableInt("alfredoPercent"),
            betoPercent = optNullableInt("betoPercent"),
            statusLabel = optString("statusLabel"),
            evidenceLabel = optString("evidenceLabel"),
        )

        private fun JSONObject.toGoalList() = GoalList(
            summary = optString("summary"),
            items = optJSONArray("items").mapObjects {
                Goal(
                    title = it.optString("title"),
                    percent = it.optInt("percent", 0).coerceIn(0, 100),
                    deadlineLabel = it.optString("deadlineLabel"),
                )
            },
        )

        private fun JSONObject.toHabitList() = HabitList(
            summary = optString("summary"),
            percent = optNullableInt("percent"),
            items = optJSONArray("items").mapObjects {
                Habit(
                    name = it.optString("name"),
                    todayLabel = it.optString("todayLabel"),
                    consistencyPercent = it.optNullableInt("consistencyPercent"),
                )
            },
        )

        private fun JSONObject.toStudy() = Study(
            minutesLabel = optString("minutesLabel", "0min"),
            sessionsLabel = optString("sessionsLabel", "0 sessões"),
            reviewsLabel = optString("reviewsLabel", "0 revisões"),
            daysLabel = optString("daysLabel", "0 dias"),
            summary = optString("summary"),
        )

        private fun JSONObject.toAgendaList() = AgendaList(
            summary = optString("summary"),
            items = optJSONArray("items").mapObjects {
                AgendaItem(
                    timeLabel = it.optString("timeLabel"),
                    title = it.optString("title"),
                    subtitle = it.optString("subtitle"),
                    isLive = it.optBoolean("isLive", false),
                )
            },
        )

        private fun JSONObject.optNullableInt(key: String): Int? =
            if (isNull(key) || !has(key)) null else optInt(key)

        private fun <T> JSONArray?.mapObjects(transform: (JSONObject) -> T): List<T> {
            if (this == null) return emptyList()
            val result = mutableListOf<T>()
            for (index in 0 until length()) {
                optJSONObject(index)?.let { result.add(transform(it)) }
            }
            return result
        }
    }
}
