# Wording of the week screens (lot 4): loads, durations, days.
module WeekHelper
  # « Mentale », « Exécution » or « Mentale et exécution ».
  def loads_label(mental, execution)
    key = if mental && execution then "both"
    elsif mental then "mental"
    else "execution"
    end
    t("week.loads.#{key}")
  end

  # 20 -> « 20 min », 65 -> « 1 h 05 », 600 -> « 10 h 00 ».
  def minutes_label(minutes)
    minutes = minutes.to_i
    return t("week.minutes", count: minutes) if minutes < 60

    format("%d h %02d", minutes / 60, minutes % 60)
  end

  def category_label(category)
    t("tasks.categories.#{category.presence || "other"}", default: category.to_s.humanize)
  end

  # « Samedi 7 nov »; « Aujourd'hui » and « Hier » when `today` is given.
  def day_label(date, today: nil)
    return t("week.today") if today && date == today
    return t("week.yesterday") if today && date == today - 1

    l(date, format: "%A %-d %b").upcase_first
  end

  # 3 -> « 3 », the ultimate level -> « ultime »: « Niveau 3 atteint », « Niveau ultime atteint ».
  def level_name(level)
    level == Progression::ULTIMATE ? t("levels.ultimate_word") : level.to_s
  end

  # « 2 nov – 8 nov » for a Week.
  def week_range_label(week)
    "#{l(week.monday, format: :short)} – #{l(week.sunday, format: :short)}"
  end

  # « mercredi 17 fév à 20:00 », in the household zone.
  def moment_label(time, zone)
    local = time.in_time_zone(zone)
    t("week.moment", day: l(local.to_date, format: "%A %-d %b"), hour: l(local, format: :hour))
  end

  # « lundi 19 oct à 3:00 »: the closing of a report, hour without a leading zero.
  def closing_label(time, zone)
    local = time.in_time_zone(zone)
    t("week.moment", day: l(local.to_date, format: "%A %-d %b"), hour: local.strftime("%-H:%M"))
  end

  # « Du 1er au 14 fév » for a pause; « Depuis le 1er fév » while it has no end.
  def pause_range_label(pause)
    if pause.ends_on
      t("pauses.range", from: l(pause.starts_on, format: :short), to: l(pause.ends_on, format: :short))
    else
      t("pauses.open", from: l(pause.starts_on, format: :short))
    end
  end

  # « jour 4 sur 14 », or « jour 4 » for a pause with no end.
  def pause_day_label(pause, today)
    day = (today - pause.starts_on).to_i + 1
    return t("pauses.day_open", day: day) unless pause.ends_on

    t("pauses.day", day: [ day, 1 ].max, total: (pause.ends_on - pause.starts_on).to_i + 1)
  end

  def hour_label(time, zone)
    l(time.in_time_zone(zone), format: :hour)
  end

  # « Chaque mois », « 2 fois par semaine »…
  def repeat_label(chore)
    key = chore.frequency
    if chore.repeating? && chore.times_per_period > 1
      t("week.repeat.#{key}_times", count: chore.times_per_period)
    else
      t("week.repeat.#{key}")
    end
  end
end
