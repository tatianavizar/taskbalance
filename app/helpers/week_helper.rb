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

  # « 2 nov – 8 nov » for a Week.
  def week_range_label(week)
    "#{l(week.monday, format: :short)} – #{l(week.sunday, format: :short)}"
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
