package com.arturoc.fitstreak

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Home screen widget: streak, next day and the week's sets. Flutter saves the
 * dates (lib/services/home_widget_sync.dart) and everything is computed here
 * with today's date, so it stays right even if the app hasn't been opened for
 * days (the same rules as StreakState in streak.dart).
 */
class StreakWidgetProvider : HomeWidgetProvider() {
    /** Redraws every widget instance from the saved [widgetData]. */
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = LocalDate.now()
        val streak = streakOn(widgetData, today)
        val daySets = parseDaySets(widgetData.getString("day_sets", "") ?: "")
        val trainedToday = (daySets[today] ?: 0) > 0
        val nextDay = widgetData.getString("next_day", null)

        val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
        val week = (0..6).map { daySets[monday.plusDays(it.toLong())] ?: 0 }
        val max = week.maxOrNull()?.coerceAtLeast(1) ?: 1
        val todayIndex = today.dayOfWeek.value - 1

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setTextViewText(R.id.streak_days, streak.days.toString())
                setTextViewText(R.id.streak_label, if (streak.days == 1) "día de racha" else "días de racha")
                val (status, color) = when {
                    trainedToday -> "Hoy ya entrenaste ✓" to "#FF4ADE80"
                    streak.days == 0 -> "Empieza hoy tu racha" to "#FFFFA94D"
                    streak.restAllowed -> "Hoy puedes descansar" to "#FFB9AEDB"
                    else -> "Entrena hoy para no perderla" to "#FFFFA94D"
                }
                setTextViewText(R.id.status, status)
                setTextColor(R.id.status, Color.parseColor(color))
                setTextViewText(R.id.next_day, if (nextDay.isNullOrBlank()) "Abre FitStreak" else "Próximo: $nextDay")

                val total = week.sum()
                setTextViewText(R.id.week_sets, if (total == 1) "1 serie" else "$total series")
                for (i in 0..6) {
                    val bar = BARS[i]
                    setImageViewResource(bar, if (i == todayIndex) R.drawable.widget_bar_today else R.drawable.widget_bar_day)
                    // Always a bit of bar on today, to see where you are.
                    val level = when {
                        week[i] > 0 -> 1500 + week[i] * 8500 / max
                        i == todayIndex -> 600
                        else -> 0
                    }
                    setInt(bar, "setImageLevel", level)
                    setTextColor(DAYS[i], Color.parseColor(if (i == todayIndex) "#FFFFFFFF" else "#FF8E83B0"))
                }
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Streak [days] and whether today can be a rest day. */
    private class Streak(val days: Int, val restAllowed: Boolean)

    /**
     * Same as StreakState.evaluate + current: freezes cover the days without
     * training; if they run out, the streak goes back to 0.
     */
    private fun streakOn(data: SharedPreferences, today: LocalDate): Streak {
        val start = date(data, "streak_start") ?: return Streak(0, false)
        var until = date(data, "protected_until") ?: return Streak(0, false)
        var freezes = data.getInt("freezes", 0)
        val yesterday = today.minusDays(1)
        while (yesterday.isAfter(until) && freezes > 0) {
            until = until.plusDays(1)
            freezes--
        }
        if (yesterday.isAfter(until)) return Streak(0, false)
        val trainedToday = date(data, "last_workout") == today
        val todayCounts = trainedToday || !today.isAfter(until)
        val days = ChronoUnit.DAYS.between(start, today).toInt() + if (todayCounts) 1 else 0
        return Streak(days, !today.isAfter(until))
    }

    /** Reads an ISO date saved under [key], or null. */
    private fun date(data: SharedPreferences, key: String): LocalDate? =
        data.getString(key, null)?.takeIf { it.isNotBlank() }?.let { runCatching { LocalDate.parse(it) }.getOrNull() }

    /** Parses "2026-10-20=19;2026-10-18=12" into sets done per day. */
    private fun parseDaySets(raw: String): Map<LocalDate, Int> =
        raw.split(';').mapNotNull { part ->
            val (d, n) = part.split('=').takeIf { it.size == 2 } ?: return@mapNotNull null
            runCatching { LocalDate.parse(d) to n.toInt() }.getOrNull()
        }.toMap()

    companion object {
        /** Bar views, Monday first. */
        private val BARS = intArrayOf(R.id.bar0, R.id.bar1, R.id.bar2, R.id.bar3, R.id.bar4, R.id.bar5, R.id.bar6)
        /** Day letter views, Monday first. */
        private val DAYS = intArrayOf(R.id.day0, R.id.day1, R.id.day2, R.id.day3, R.id.day4, R.id.day5, R.id.day6)
    }
}
