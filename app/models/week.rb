# A calendar week, Monday 00:00 to Sunday 23:59:59 in a given time zone.
#
# Every weekly rule of the product (balance, streaks, closing) is computed in
# the household's time zone, never in UTC. Boundaries are built from local
# dates, so a daylight-saving change inside the week simply makes the week
# 167 or 169 hours long, and the boundaries stay on local midnight.
#
#   week = Week.containing(Time.current, "Europe/Paris")
#   week.label       # => "Semaine 41"
#   week.date_range  # => Mon, 05 Oct 2026..Sun, 11 Oct 2026
#   ChoreLog.where(completed_at: week.range)
class Week
  include Comparable

  attr_reader :time_zone, :monday

  # time_or_date: a Time/TimeWithZone (read in the given zone) or a Date.
  def self.containing(time_or_date, time_zone = "Europe/Paris")
    zone = ActiveSupport::TimeZone[time_zone.to_s] || raise(ArgumentError, "unknown time zone: #{time_zone.inspect}")
    date =
      if time_or_date.respond_to?(:in_time_zone)
        time_or_date.is_a?(Date) && !time_or_date.is_a?(DateTime) ? time_or_date : time_or_date.in_time_zone(zone).to_date
      else
        raise ArgumentError, "expected a Time or a Date"
      end
    new(date.beginning_of_week(:monday), zone)
  end

  def self.current(time_zone = "Europe/Paris")
    containing(Time.current, time_zone)
  end

  def initialize(monday, zone)
    @monday = monday
    @time_zone = zone
  end

  # Monday 00:00 local.
  def start_at
    time_zone.local(monday.year, monday.month, monday.day)
  end

  # Sunday 23:59:59 local (end of the last second).
  def end_at
    sunday = monday + 6
    time_zone.local(sunday.year, sunday.month, sunday.day).end_of_day
  end

  # Inclusive range of instants, usable in `where(completed_at: week.range)`.
  def range
    start_at..end_at
  end

  # Monday..Sunday as dates.
  def date_range
    monday..(monday + 6)
  end

  def sunday
    monday + 6
  end

  # ISO 8601 week number and the year it belongs to (the first days of January
  # can be in week 52/53 of the previous year).
  def number
    monday.cweek
  end

  def year
    monday.cwyear
  end

  def label
    I18n.t("weeks.label", number: number, default: "Semaine %{number}")
  end

  def cover?(time)
    range.cover?(time)
  end

  def previous
    self.class.new(monday - 7, time_zone)
  end

  def next
    self.class.new(monday + 7, time_zone)
  end

  def <=>(other)
    return nil unless other.is_a?(Week)

    monday <=> other.monday
  end

  def ==(other)
    other.is_a?(Week) && monday == other.monday && time_zone.name == other.time_zone.name
  end
  alias_method :eql?, :==

  def hash
    [ monday, time_zone.name ].hash
  end
end
