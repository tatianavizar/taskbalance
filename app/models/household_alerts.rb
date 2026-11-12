# What the home and the Bilan tab flag to one person (E3, E4, E5, E8, E11, E13,
# E15, D13). Read only: every fact comes from what the engine stored
# (households, household_members, absence_inquiries, level_changes,
# engine_events, household_weeks) and from WeeklyStats for the current week.
# Facts are the same for every member (D8); the views pick « vous » or the
# first name. No streak, no countdown: an alert says what happened and what
# can be done about it.
#
#   alerts = HouseholdAlerts.new(household, user)
#   alerts.all    # => [Alert], most pressing first
#
# Kinds, in this order:
#   :blocked      the household regressed and is blocked (E4; E15 for the person
#                 concerned). data: level, concerned (members), from, to (dates),
#                 weeks, open_inquiries (regressions a pause can still cancel),
#                 viewer_concerned, progress (current week: [{ name:, count: }])
#   :inquiry      an absence question is open (E11, P5). data: inquiry,
#                 viewer_answered, viewer_concerned
#   :first_empty  a member's first empty week (E3, D13), shown until they log
#                 again. data: member, viewer_concerned, week (the empty week),
#                 week_label, from, to, tally ([{week:, count:}], the 4 last
#                 closed weeks), others_count, others_names
#   :unblocked    the last final week lifted the block (E5). data: week_start, balanced
#   :level        a level move since Monday: reached (E8), ultimate_lost (E13),
#                 ultimate_regained, regression_cancelled (D3), membership_changed.
#                 data: change
class HouseholdAlerts
  Alert = Data.define(:kind, :data)

  LEVEL_REASONS = %w[reached ultimate_lost ultimate_regained regression_cancelled membership_changed].freeze

  attr_reader :household, :viewer

  def initialize(household, viewer, now: Time.current)
    @household = household
    @viewer = viewer
    @now = now
  end

  def all
    @all ||= [ blocked, *inquiries, *first_empty_weeks, unblocked, level_move ].compact
  end

  def any? = all.any?

  def week
    @week ||= household.week_containing(@now)
  end

  def stats
    @stats ||= WeeklyStats.new(household, week)
  end

  private

  def alert(kind, **data) = Alert.new(kind: kind, data: data)

  def memberships
    @memberships ||= household.household_members.includes(:user).order(:created_at, :id).to_a
  end

  def viewer_membership
    memberships.find { |member| member.user_id == viewer.id }
  end

  # ---- E4 / E15 ---------------------------------------------------------------

  def blocked
    return unless household.blocked?

    inquiries = household.absence_inquiries.regressed.includes(household_member: :user)
    inquiries = inquiries.where(deadline_at: household.blocked_at..) if household.blocked_at
    inquiries = inquiries.order(:deadline_at, :id).to_a
    concerned = inquiries.map(&:household_member).uniq
    concerned = memberships.select { |m| m.empty_weeks_streak >= 2 } if concerned.empty?
    return if concerned.empty?

    weeks = [ concerned.map(&:empty_weeks_streak).max, 2 ].max
    from = inquiries.map(&:first_week_start).min
    to = inquiries.map { |i| i.last_week_start + 6 }.max

    alert(:blocked, level: household.level, concerned: concerned, weeks: weeks, from: from, to: to,
                        open_inquiries: inquiries.select(&:correction_window_open?),
                        viewer_concerned: concerned.any? { |m| m.user_id == viewer.id },
                        progress: stats.active_members.map { |m| { name: m.first_name, user_id: m.user_id, count: m.logs_count } })
  end

  # ---- E11 / P5 ---------------------------------------------------------------

  def inquiries
    membership = viewer_membership
    return [] unless membership

    AbsenceInquiry.open_for(household, @now).includes(:absence_answers, household_member: :user).map do |inquiry|
      alert(:inquiry, inquiry: inquiry, viewer_answered: inquiry.answer_for(membership).present?,
                          viewer_concerned: inquiry.household_member_id == membership.id)
    end
  end

  # ---- E3 / D13 ---------------------------------------------------------------

  def first_empty_weeks
    return [] if household.blocked?

    memberships.select { |m| m.empty_weeks_streak == 1 }.filter_map do |member|
      line = stats.member_for(member.user_id)
      next if line.nil? || line.paused || line.logs_count.positive?

      closed = last_closed_week
      next unless closed

      empty_week_alert(member, closed)
    end
  end

  def last_closed_week
    @last_closed_week ||= household.household_weeks.final.order(week_start: :desc).first
  end

  def empty_week_alert(member, closed)
    snapshot = closed.member_snapshot(member.user_id)
    return if snapshot.nil? || snapshot["logs_count"].to_i.positive?

    tally = household.household_weeks.final.order(week_start: :desc).limit(4).to_a.reverse.filter_map do |hw|
      mine = hw.member_snapshot(member.user_id)
      { week: hw.week, count: mine["logs_count"].to_i } if mine
    end
    rest = closed.members.reject { |m| m["user_id"] == member.user_id }
    others = rest.sum { |m| m["logs_count"].to_i }
    others_names = rest.map { |m| m["first_name"] }
    alert(:first_empty, member: member, viewer_concerned: member.user_id == viewer.id, week: closed.week,
                            week_label: closed.week.label, from: closed.week.monday, to: closed.week.sunday,
                            tally: tally, others_count: others, others_names: others_names)
  end

  # ---- E5 ---------------------------------------------------------------------

  def unblocked
    return if household.blocked?

    event = household.engine_events.where(name: "household.unblocked", occurred_at: week.start_at..).order(:occurred_at).last
    return unless event

    week_start = Date.iso8601(event.payload["week_start"])
    record = household.household_weeks.find_by(week_start: week_start)
    alert(:unblocked, week_start: week_start, balanced: record&.effective_outcome == "balanced")
  end

  # ---- E8 / E13 ---------------------------------------------------------------

  def level_move
    change = household.level_changes.where(reason: LEVEL_REASONS, created_at: week.start_at..).chronological.last
    alert(:level, change: change) if change
  end
end
