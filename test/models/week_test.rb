require "test_helper"

class WeekTest < ActiveSupport::TestCase
  PARIS = "Europe/Paris".freeze

  def paris(*args) = ActiveSupport::TimeZone[PARIS].local(*args)

  test "a mid-week moment gives Monday 00:00 to Sunday 23:59:59 local" do
    week = Week.containing(paris(2026, 10, 8, 14, 30), PARIS) # Thursday

    assert_equal paris(2026, 10, 5, 0, 0, 0), week.start_at
    assert_equal paris(2026, 10, 11, 23, 59, 59), week.end_at.change(usec: 0)
    assert_equal Date.new(2026, 10, 5)..Date.new(2026, 10, 11), week.date_range
  end

  test "Sunday 23:59:59 is still in the week, Monday 00:00 starts the next one" do
    sunday_last_second = paris(2026, 10, 11, 23, 59, 59)
    monday_first_second = paris(2026, 10, 12, 0, 0, 0)

    assert_equal Date.new(2026, 10, 5), Week.containing(sunday_last_second, PARIS).monday
    assert_equal Date.new(2026, 10, 12), Week.containing(monday_first_second, PARIS).monday
    assert Week.containing(sunday_last_second, PARIS).cover?(sunday_last_second)
    assert_not Week.containing(sunday_last_second, PARIS).cover?(monday_first_second)
  end

  test "the zone decides which week an instant belongs to" do
    instant = Time.utc(2026, 10, 11, 22, 30) # Sunday 22:30 UTC = Monday 00:30 in Paris (UTC+2)

    assert_equal Date.new(2026, 10, 12), Week.containing(instant, "Europe/Paris").monday
    assert_equal Date.new(2026, 10, 5), Week.containing(instant, "UTC").monday
    assert_equal Date.new(2026, 10, 5), Week.containing(instant, "America/New_York").monday
  end

  test "the ISO week number and the label" do
    week = Week.containing(Date.new(2026, 10, 8), PARIS)

    assert_equal 41, week.number
    assert_equal 2026, week.year
    assert_equal "Semaine 41", week.label
  end

  test "early January can belong to the last week of the previous year" do
    week = Week.containing(Date.new(2027, 1, 1), PARIS) # Friday

    assert_equal Date.new(2026, 12, 28), week.monday
    assert_equal 53, week.number
    assert_equal 2026, week.year
  end

  test "the spring clock change shortens the week and boundaries stay at local midnight" do
    week = Week.containing(Date.new(2026, 3, 29), PARIS) # Sunday of the change (02:00 -> 03:00)

    assert_equal paris(2026, 3, 23, 0, 0, 0), week.start_at
    assert_equal 0, week.start_at.hour
    assert_equal 23, week.end_at.hour
    assert_equal 59, week.end_at.min
    assert_equal 167 * 3600 - 1, (week.end_at.change(usec: 0) - week.start_at).to_i
    assert_equal Date.new(2026, 3, 29), week.end_at.to_date
  end

  test "the autumn clock change lengthens the week" do
    week = Week.containing(Date.new(2026, 10, 25), PARIS) # Sunday of the change (03:00 -> 02:00)

    assert_equal 169 * 3600 - 1, (week.end_at.change(usec: 0) - week.start_at).to_i
    assert_equal 0, week.start_at.hour
    assert_equal 23, week.end_at.hour
  end

  test "a log written just after the change is attributed to the right week" do
    after_change = paris(2026, 3, 29, 3, 30)
    assert_equal Date.new(2026, 3, 23), Week.containing(after_change, PARIS).monday
    assert_equal Date.new(2026, 3, 30), Week.containing(after_change + 21.hours, PARIS).monday
  end

  test "previous, next and ordering" do
    week = Week.containing(Date.new(2026, 10, 8), PARIS)

    assert_equal Date.new(2026, 10, 12), week.next.monday
    assert_equal Date.new(2026, 9, 28), week.previous.monday
    assert_operator week.previous, :<, week
    assert_equal week, Week.containing(Date.new(2026, 10, 11), PARIS)
  end

  test "an unknown zone is refused" do
    assert_raises(ArgumentError) { Week.containing(Date.today, "Mars/Olympus") }
  end

  test "current reads the clock in the zone" do
    travel_to Time.utc(2026, 10, 11, 22, 30) do
      assert_equal Date.new(2026, 10, 12), Week.current("Europe/Paris").monday
    end
  end
end
