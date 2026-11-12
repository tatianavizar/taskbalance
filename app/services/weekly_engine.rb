# The weekly engine of one household (docs/backend-backlog.md 2.1, 2.2, 2.2b).
#
#   WeeklyEngine.new(household).run(now: Time.current) # => WeeklyEngine::Result
#
# Each run, under a row lock on the household, acts on every moment that has
# passed in the household's time zone, in order:
#   1. final report of every week whose Monday 03:00 has passed and that is not
#      final yet, oldest first (catch-up of missed weeks). Before each one, the
#      absence inquiries due before that closing are resolved;
#   2. the absence inquiries due by `now` (Wednesday 20:00);
#   3. the provisional report, once, from Sunday 20:00 until the closing.
# Re-running is harmless: a final week is never rewritten, a provisional one is
# written once, inquiries are keyed by member and week.
#
# Final report effects (the only place where progression moves):
# - balanced week, household not blocked: +1 balanced week, level up when a
#   threshold is reached (Progression);
# - unbalanced or neutral week: nothing moves;
# - empty-week streaks: a member present all week, not paused, with no log gets
#   +1; any log, or a pause, sets it back to 0. A member who arrived that week
#   keeps their streak. A week where *nobody* active logged is a silent week:
#   streaks are left as they are and the household counts towards dormant
#   (3 silent weeks, default not yet validated). Households of fewer than two
#   members keep no streaks;
# - streak reaching 2: an AbsenceInquiry, deadline Wednesday 20:00;
# - blocked household: unblocked by the first final week where every active
#   member logged at least once; that week then counts normally.
# Inquiry deadline without a covering pause: one level down, counter at the
# threshold of the new level, household blocked. Already blocked: no second drop.
class WeeklyEngine
  Result = Struct.new(:provisional_weeks, :final_weeks, :level_changes,
                      :inquiries_opened, :inquiries_resolved, :unblocked) do
    def initialize(*)
      super([], [], [], [], [], false)
    end
  end

  SILENT_WEEKS_FOR_DORMANT = 3 # default, not yet validated (backlog 2.2)

  def self.run_all(now: Time.current)
    Household.find_each do |household|
      new(household).run(now: now)
    rescue StandardError => e
      Rails.error.report(e, context: { household_id: household.id })
    end
  end

  attr_reader :household

  def initialize(household)
    @household = household
  end

  def run(now: Time.current)
    result = Result.new
    household.with_lock do
      next unless household.household_members.exists?

      weeks_to_finalize(now).each do |week|
        resolve_due_inquiries(HouseholdWeek.final_at(week), result)
        finalize(week, now, result)
      end
      resolve_due_inquiries(now, result)
      write_provisional(now, result)
    end
    result
  end

  # What a retroactive pause changed on final weeks (D3).
  Correction = Struct.new(:corrections, :level_changes) do
    def initialize(*)
      super([], [])
    end
  end

  # Called after a MemberPause is created. A pause that covers a pending
  # inquiry's weeks resolves it now: no regression. A pause over final weeks
  # goes through retroactive_pause_on_final_weeks (D3).
  def pause_declared(pause, now: Time.current)
    correction = Correction.new
    household.with_lock do
      household.absence_inquiries.pending.where(household_member_id: pause.household_member_id).find_each do |inquiry|
        next unless inquiry.weeks.any? { |week| pause.covers?(week) }

        resolve_as_paused(inquiry, now)
      end

      range = (pause.starts_on - 6)..pause.ends_on
      covered_final = household.household_weeks.final.where(week_start: range).select { |hw| pause.covers?(hw.week) }
      correction = retroactive_pause_on_final_weeks(pause, covered_final, now: now) if covered_final.any?
      refresh_state!
    end
    correction
  end

  # D3 (decision 2026-11-12): a pause declared after the fact over final weeks.
  # - The stored reports are never rewritten: a WeekCorrection is laid over
  #   each covered final week (« Neutre · pause déclarée le … »).
  # - Only weeks inside the retroactive-pause window are corrected: the last
  #   14 days, or the weeks of an absence inquiry or regression until the next
  #   final report after its deadline. Outside it, nothing happens.
  # - A regression applied because of those weeks is cancelled: level and
  #   counter restored from the regression's LevelChange, block lifted (unless
  #   another member's regression still stands), and a regression_cancelled
  #   LevelChange logged. The inquiry becomes `cancelled`.
  # - The member's empty-week streak is recomputed from the final reports and
  #   corrections, so it reads as if the pause had been there.
  # Idempotent: a second call corrects and cancels nothing more.
  def retroactive_pause_on_final_weeks(pause, final_weeks, now: Time.current)
    correction = Correction.new
    membership = pause.household_member
    final_weeks.each do |household_week|
      next unless correctable?(household_week, membership, now)

      record = household_week.week_corrections.find_or_create_by!(user_id: membership.user_id) do |c|
        c.household = household
        c.member_pause = pause
        c.declared_by_id = pause.declared_by_id
        c.first_name = membership.user.first_name
        c.declared_at = pause.created_at || now
      end
      correction.corrections << record if record.previously_new_record?
    end

    household.absence_inquiries.regressed.where(household_member: membership).order(:deadline_at).each do |inquiry|
      next unless inquiry.correction_window_open?(now) && inquiry.weeks.any? { |week| pause.covers?(week) }

      change = cancel_regression!(inquiry, now)
      correction.level_changes << change if change
    end

    recompute_streak!(membership)
    correction
  end

  private

  def correctable?(household_week, membership, now)
    snapshot = household_week.member_snapshot(membership.user_id)
    return false if snapshot.nil? || snapshot["paused"] || snapshot["logs_count"].to_i.positive?

    week = household_week.week
    in_last_days = week.sunday >= now.in_time_zone(zone).to_date - MemberPause::RETROACTIVE_DAYS
    in_last_days || household.absence_inquiries.where(household_member: membership).any? do |inquiry|
      inquiry.covers_week?(week) && inquiry.correction_window_open?(now)
    end
  end

  def cancel_regression!(inquiry, now)
    inquiry.update!(status: "cancelled", resolved_at: now)
    return unless household.blocked?
    # Another member's regression applied during the same block still stands.
    return if household.absence_inquiries.regressed.where(deadline_at: household.blocked_at..).exists?

    regression = household.level_changes.standing_regressions.chronological.last
    if regression.nil? || household.level_changes.chronological.last != regression
      household.update!(state: "active", blocked_at: nil)
      return
    end

    change = record_level_change(household.level, regression.from_level, household.balanced_weeks_count,
                                 regression.balanced_weeks_count_before, :regression_cancelled,
                                 week_start: regression.week_start, absence_inquiry: inquiry,
                                 cancelled_level_change: regression)
    household.update!(level: regression.from_level, balanced_weeks_count: regression.balanced_weeks_count_before,
                      state: "active", blocked_at: nil)
    change
  end

  # The streak as the final reports and corrections tell it: consecutive most
  # recent final weeks where the member, present and not paused (nor
  # corrected), logged nothing. Same skips as update_streaks: households under
  # two members, silent weeks, the member's arrival week.
  def recompute_streak!(membership)
    streak = 0
    household.household_weeks.final.includes(:week_corrections).order(week_start: :desc).each do |household_week|
      snapshot = household_week.member_snapshot(membership.user_id)
      break if snapshot.nil?

      members = household_week.members
      next if members.size < 2

      corrected = household_week.week_corrections.map(&:user_id)
      paused = ->(m) { m["paused"] || corrected.include?(m["user_id"]) }
      active = members.reject(&paused)
      next if active.any? && active.all? { |m| m["logs_count"].to_i.zero? }
      break if paused.(snapshot) || snapshot["logs_count"].to_i.positive?
      next if snapshot["arrived"]

      streak += 1
    end
    membership.update!(empty_weeks_streak: streak) if membership.empty_weeks_streak != streak
  end

  def zone
    household.zone
  end

  def weeks_to_finalize(now)
    last_final = household.household_weeks.final.maximum(:week_start)
    week = last_final ? Week.new(last_final + 7, zone) : household.week_containing(household.created_at)
    weeks = []
    while HouseholdWeek.final_at(week) <= now
      weeks << week
      week = week.next
    end
    weeks
  end

  def write_provisional(now, result)
    current = household.week_containing(now)
    [ current.previous, current ].each do |week|
      next unless HouseholdWeek.provisional_at(week) <= now && now < HouseholdWeek.final_at(week)
      next if week.end_at < household.created_at
      next if household.household_weeks.exists?(week_start: week.monday)

      stats = WeeklyStats.new(household, week)
      result.provisional_weeks << household.household_weeks.create!(
        stats.to_snapshot.merge(status: "provisional", computed_at: now)
      )
    end
  end

  def finalize(week, now, result)
    stats = WeeklyStats.new(household, week)
    record = household.household_weeks.find_or_initialize_by(week_start: week.monday)
    return if record.final?

    record.update!(stats.to_snapshot.merge(status: "final", computed_at: now, finalized_at: now))
    result.final_weeks << record

    update_streaks(stats, week, now, result)
    unblock_if_everyone_logged(stats, result)
    progress(stats, record, week, result)
    refresh_state!
  end

  def update_streaks(stats, week, now, result)
    return if stats.members.size < 2

    active = stats.active_members
    if active.any? && active.all?(&:empty?)
      household.increment(:silent_weeks_count)
      household.save!
      return
    end
    household.update!(silent_weeks_count: 0) unless household.silent_weeks_count.zero?

    memberships = household.household_members.index_by(&:id)
    stats.members.each do |member|
      membership = memberships[member.household_member_id] or next
      next if member.arrived && !member.paused && member.empty?

      streak = member.paused || !member.empty? ? 0 : membership.empty_weeks_streak + 1
      membership.update!(empty_weeks_streak: streak) if streak != membership.empty_weeks_streak
      open_inquiry(membership, week, result) if streak == 2
    end
  end

  def open_inquiry(membership, week, result)
    inquiry = household.absence_inquiries.find_or_create_by!(household_member: membership, last_week_start: week.monday) do |i|
      i.first_week_start = week.previous.monday
      i.deadline_at = AbsenceInquiry.deadline_for(week)
    end
    result.inquiries_opened << inquiry if inquiry.previously_new_record?
  end

  def resolve_due_inquiries(before, result)
    household.absence_inquiries.due(before).includes(:household_member).order(:deadline_at, :id).each do |inquiry|
      if inquiry.covered_by_pause?
        resolve_as_paused(inquiry, before)
      elsif (change = regress!(inquiry))
        result.level_changes << change
      end
      result.inquiries_resolved << inquiry
    end
    refresh_state!
  end

  def resolve_as_paused(inquiry, at)
    inquiry.update!(status: "paused", resolved_at: at)
    inquiry.household_member.update!(empty_weeks_streak: 0)
  end

  def regress!(inquiry)
    inquiry.update!(status: "regressed", resolved_at: inquiry.deadline_at)
    return if household.blocked?

    from = household.level
    to = Progression.regressed_level(from)
    change = record_level_change(from, to, household.balanced_weeks_count, Progression.threshold(to), :regressed,
                                 week_start: inquiry.last_week_start, absence_inquiry: inquiry)
    household.update!(level: to, balanced_weeks_count: Progression.threshold(to),
                      state: "blocked", blocked_at: inquiry.deadline_at)
    change
  end

  def unblock_if_everyone_logged(stats, result)
    return unless household.blocked?

    active = stats.active_members
    return unless active.any? && active.none?(&:empty?)

    household.update!(state: "active", blocked_at: nil)
    result.unblocked = true
  end

  def progress(stats, record, week, result)
    return if household.blocked?

    from = household.level
    count_before = household.balanced_weeks_count
    count = count_before + (stats.balanced? ? 1 : 0)
    threshold = Progression.threshold(Progression::ULTIMATE)

    to, reason =
      if stats.balanced? && count == threshold && count_before < threshold
        [ Progression::ULTIMATE, :reached ]
      elsif count >= threshold
        keeps = Progression.keeps_ultimate?(household, week)
        if from == Progression::ULTIMATE && !keeps then [ Progression::ULTIMATE - 1, :ultimate_lost ]
        elsif from < Progression::ULTIMATE && keeps then [ Progression::ULTIMATE, :ultimate_regained ]
        end
      elsif Progression.level_for(count) > from
        [ Progression.level_for(count), :reached ]
      end

    if to && to != from
      result.level_changes << record_level_change(from, to, count_before, count, reason, week_start: week.monday, household_week: record)
    end
    attrs = { level: to || from, balanced_weeks_count: count }
    # The ultimate window starts at the first time the level was reached; it
    # is never moved by a loss, a regain or a regression.
    attrs[:ultimate_reached_on] = week.monday if to == Progression::ULTIMATE && household.ultimate_reached_on.nil?
    household.update!(attrs)
  end

  def record_level_change(from, to, before, after, reason, **attrs)
    household.level_changes.create!(from_level: from, to_level: to, balanced_weeks_count_before: before,
                                    balanced_weeks_count_after: after, reason: reason, **attrs)
  end

  def refresh_state!
    return if household.setting_up?

    state =
      if household.blocked? then "blocked"
      elsif household.household_members.count < 2 then "solo"
      elsif household.silent_weeks_count >= SILENT_WEEKS_FOR_DORMANT then "dormant"
      elsif household.household_members.where(empty_weeks_streak: 1..).exists? then "warned"
      else "active"
      end
    household.update!(state: state) if household.state != state
  end
end
