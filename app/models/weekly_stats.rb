# The balance of one household over one local week, computed live from the
# members' ChoreLogs. Not persisted: the weekly engine snapshots it into
# HouseholdWeek, and home screens read it directly for the current week.
#
# == Interface (fixed at the start of lot 5a; lot 4 consumes it)
#
#   stats = WeeklyStats.new(household, week = household.current_week)
#
#   stats.week            # => Week
#   stats.members         # => [WeeklyStats::Member], every member present at
#                         #    some point of the week, in arrival order
#   stats.active_members  # => members who count: present since Monday 00:00
#                         #    or arrived during the week, and not paused
#   stats.member_for(user_or_id) # => WeeklyStats::Member or nil
#   stats.fair_share      # => Integer, HouseholdRules.fair_share(active members); nil if none
#   stats.zone            # => Range, HouseholdRules.zone(active members); nil if none
#   stats.mental_total    # => Integer, mental-load logs of the active members
#   stats.execution_total # => Integer, execution logs of the active members
#   stats.minutes_total   # => Integer, minutes of the active members (shown, never judged)
#   stats.mental_by_category # => { "cooking" => 4, "other" => 1, ... } (active members)
#   stats.outcome         # => :balanced, :unbalanced or :neutral
#   stats.neutral_reason  # => nil, or one of NEUTRAL_REASONS
#   stats.balanced? / unbalanced? / neutral?
#   stats.pauses          # => [MemberPause] overlapping the week
#   stats.to_snapshot     # => Hash of HouseholdWeek attributes
#
# WeeklyStats::Member fields:
#   household_member_id, user_id, first_name, color, monogram,
#   mental_count, execution_count, minutes, logs_count  (Integers, own logs of the week)
#   mental_share, execution_share  (Integer percent of the active totals, rounded
#                                   half up, FOR DISPLAY; nil when paused or
#                                   when that total is 0)
#   mental_share_exact, execution_share_exact (Rational percent, unrounded,
#                                   same nil cases: the value the zone judges)
#   paused, arrived               (Booleans: arrived = joined after Monday 00:00)
#   in_zone_mental, in_zone_execution, in_zone (Booleans; false when paused)
#   active?                       (not paused)
#
# == Rules (docs/backend-backlog.md, "Product rules")
# - A log counts in the week of its `completed_at`, read in the household zone.
# - Only logs carrying this household_id count. A log whose chore was deleted
#   (chore_id nil) still counts; a custom chore (task_id nil) counts like any other.
# - The zone check uses the exact share; rounding is for display only. The
#   fair share itself is rounded (100 / 3 -> 33). Two members: 40.0 % and
#   60.0 % are in the 40-60 zone; 39.5 % (shown "40 %") and 60.4 % are not.
# - Every number (zone, fair share) comes from HouseholdRules.
# - Fair share uses the number of *active* members: a paused member is not
#   active, so a household of 3 with one person paused judges the other two on 50 %.
#   Logs of a paused member are shown on their line but left out of the shares.
# - A member who left the household no longer has a membership and is not in
#   the week (their logs follow them, see CLAUDE.md).
# - Neutral (nothing moves), checked in this order:
#   too_few_active_members (fewer than 2), member_arrived (someone joined after
#   Monday 00:00: the arrival week counts for nobody), no_mental_logs, no_execution_logs.
class WeeklyStats
  NEUTRAL_REASONS = %i[too_few_active_members member_arrived no_mental_logs no_execution_logs].freeze

  Member = Data.define(
    :household_member_id, :user_id, :first_name, :color, :monogram,
    :mental_count, :execution_count, :minutes, :logs_count,
    :mental_share, :execution_share, :mental_share_exact, :execution_share_exact,
    :paused, :arrived,
    :in_zone_mental, :in_zone_execution
  ) do
    def in_zone = in_zone_mental && in_zone_execution
    def active? = !paused
    def empty? = logs_count.zero?

    # Exact shares are stored as floats (JSON has no rationals).
    def to_snapshot
      to_h.merge(
        mental_share_exact: mental_share_exact&.to_f,
        execution_share_exact: execution_share_exact&.to_f,
        in_zone: in_zone
      ).stringify_keys
    end
  end

  attr_reader :household, :week

  def self.fair_share_for(count)
    HouseholdRules.fair_share(count)
  end

  def initialize(household, week = household.current_week)
    @household = household
    @week = week
  end

  def members
    @members ||= build_members
  end

  def active_members
    members.select(&:active?)
  end

  def member_for(user_or_id)
    id = user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
    members.find { |m| m.user_id == id }
  end

  def fair_share
    self.class.fair_share_for(active_memberships.size)
  end

  def zone
    HouseholdRules.zone(active_memberships.size)
  end

  def mental_total = active_members.sum(&:mental_count)
  def execution_total = active_members.sum(&:execution_count)
  def minutes_total = active_members.sum(&:minutes)

  def mental_by_category
    @mental_by_category ||= active_logs.where(mental_load: true)
      .group(:category).count
      .each_with_object(Hash.new(0)) { |(category, n), h| h[category.presence || "other"] += n }
  end

  def neutral_reason
    return @neutral_reason if defined?(@neutral_reason)

    @neutral_reason =
      if active_members.size < 2 then :too_few_active_members
      elsif members.any?(&:arrived) then :member_arrived
      elsif mental_total.zero? then :no_mental_logs
      elsif execution_total.zero? then :no_execution_logs
      end
  end

  def outcome
    if neutral_reason then :neutral
    elsif active_members.all?(&:in_zone) then :balanced
    else :unbalanced
    end
  end

  def balanced? = outcome == :balanced
  def unbalanced? = outcome == :unbalanced
  def neutral? = outcome == :neutral

  # MemberPause rows overlapping the week, for members present that week.
  def pauses
    @pauses ||= MemberPause.where(household_member_id: memberships.map(&:id)).overlapping(week).order(:starts_on).to_a
  end

  # Attributes for HouseholdWeek (status and timestamps are set by the engine).
  # The pause reason is private and never copied.
  def to_snapshot
    {
      week_start: week.monday,
      time_zone: week.time_zone.tzinfo.name,
      outcome: outcome.to_s,
      neutral_reason: neutral_reason&.to_s,
      fair_share: fair_share,
      mental_total: mental_total,
      execution_total: execution_total,
      minutes_total: minutes_total,
      members: members.map(&:to_snapshot),
      pauses: pauses.map do |pause|
        member = members.find { |m| m.household_member_id == pause.household_member_id }
        {
          "household_member_id" => pause.household_member_id,
          "user_id" => member&.user_id,
          "first_name" => member&.first_name,
          "starts_on" => pause.starts_on.iso8601,
          "ends_on" => pause.ends_on&.iso8601,
          "declared_by_id" => pause.declared_by_id
        }
      end
    }
  end

  private

  # Memberships that existed at some point of the week (joined before it ended).
  def memberships
    @memberships ||= household.household_members.includes(:user)
      .where(created_at: ..week.end_at).order(:created_at, :id).to_a
  end

  def paused_membership_ids
    @paused_membership_ids ||= pauses.map(&:household_member_id).to_set
  end

  def active_memberships
    memberships.reject { |m| paused_membership_ids.include?(m.id) }
  end

  def week_logs
    ChoreLog.where(household_id: household.id, user_id: memberships.map(&:user_id), completed_at: week.range)
  end

  def active_logs
    week_logs.where(user_id: active_memberships.map(&:user_id))
  end

  def counts_by_user
    @counts_by_user ||= week_logs.group(:user_id).pluck(
      :user_id,
      Arel.sql("COUNT(*) FILTER (WHERE mental_load)"),
      Arel.sql("COUNT(*) FILTER (WHERE execution_load)"),
      Arel.sql("COALESCE(SUM(time_spent), 0)"),
      Arel.sql("COUNT(*)")
    ).to_h { |user_id, *counts| [ user_id, counts.map(&:to_i) ] }
  end

  def build_members
    active_ids = active_memberships.map(&:user_id).to_set
    totals = [ 0, 0 ]
    counts_by_user.each do |user_id, (mental, execution, _, _)|
      next unless active_ids.include?(user_id)

      totals[0] += mental
      totals[1] += execution
    end
    zone = self.zone

    memberships.map do |membership|
      mental, execution, minutes, logs = counts_by_user.fetch(membership.user_id, [ 0, 0, 0, 0 ])
      paused = paused_membership_ids.include?(membership.id)
      mental_exact = paused ? nil : exact_percent(mental, totals[0])
      execution_exact = paused ? nil : exact_percent(execution, totals[1])

      Member.new(
        household_member_id: membership.id,
        user_id: membership.user_id,
        first_name: membership.user.first_name,
        color: membership.color,
        monogram: membership.monogram,
        mental_count: mental,
        execution_count: execution,
        minutes: minutes,
        logs_count: logs,
        mental_share: mental_exact&.round,
        execution_share: execution_exact&.round,
        mental_share_exact: mental_exact,
        execution_share_exact: execution_exact,
        paused: paused,
        arrived: membership.created_at > week.start_at,
        in_zone_mental: in_zone?(mental_exact, zone),
        in_zone_execution: in_zone?(execution_exact, zone)
      )
    end
  end

  # Rational percent, never rounded: the zone judges this value.
  def exact_percent(count, total)
    return nil if total.zero?

    count * 100r / total
  end

  def in_zone?(exact_share, zone)
    return false if exact_share.nil? || zone.nil?

    zone.cover?(exact_share)
  end
end
