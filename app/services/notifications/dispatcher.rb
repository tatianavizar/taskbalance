module Notifications
  # Turns what the weekly engine did into events and hands them to the
  # Notifier. The engine is not touched: this reads the WeeklyEngine::Result
  # it returned (the new reports, level changes, inquiries) and the records
  # those point to.
  #
  #   result = WeeklyEngine.new(household).run(now: now)
  #   Notifications::Dispatcher.engine_result(household, result, now: now)
  #
  # What comes out of a run:
  #   provisional report      -> H3 weekly report
  #   final report            -> E3 alert for each member who logged nothing
  #                              (unless that week opened an inquiry: the
  #                              question below says it), E5 when it lifted
  #                              the block
  #   inquiry opened          -> the absence question (E11, P5)
  #   level change regressed  -> E4 alert, block
  #   regression_cancelled    -> absence outcome "cancelled"
  #   inquiry resolved paused -> absence outcome "paused"
  #
  # A pause declared outside a run (WeeklyEngine#pause_declared) has no
  # Result; the code that declares it calls `pause_declared`.
  class Dispatcher
    def self.engine_result(household, result, now: Time.current)
      new(household, now).engine_result(result)
    end

    def self.pause_declared(pause, correction: nil, now: Time.current)
      new(pause.household, now).pause_declared(pause, correction)
    end

    def initialize(household, now)
      @household = household
      @now = now
    end

    def engine_result(result)
      result.provisional_weeks.each { |week| send_event Events::WeeklyReport.new(week) }

      result.final_weeks.each do |week|
        no_logs_alerts(week)
      end
      unblocked_alert(result) if result.unblocked

      result.inquiries_opened.each { |inquiry| send_event Events::AbsenceQuestion.new(inquiry) }
      result.level_changes.each { |change| level_change(change) }
      result.inquiries_resolved.select(&:paused?).each { |inquiry| paused_outcome(inquiry) }
    end

    # Everyone is told the dates (backlog 2.3); every inquiry the pause
    # resolved gets its outcome, every regression it cancelled too.
    def pause_declared(pause, correction)
      send_event Events::PauseDeclared.new(pause)
      @household.absence_inquiries.paused.where(household_member_id: pause.household_member_id).find_each do |inquiry|
        paused_outcome(inquiry, pause) if inquiry.weeks.any? { |week| pause.covers?(week) }
      end
      Array(correction&.level_changes).each { |change| level_change(change) }
    end

    private

    def send_event(event)
      Notifier.call(event, now: @now)
    end

    # E3. Not for a household of one, not for a week nobody logged in (it is
    # silent, not a member's absence), not for a paused member or one who
    # arrived that week.
    def no_logs_alerts(week)
      return if week.members.size < 2

      active = week.members.reject { |m| m["paused"] }
      return if active.none? { |m| m["logs_count"].to_i.positive? }

      active.each do |snapshot|
        next if snapshot["logs_count"].to_i.positive? || snapshot["arrived"]
        next if @household.absence_inquiries.exists?(household_member_id: snapshot["household_member_id"], last_week_start: week.week_start)

        send_event Events::NoLogsAlert.new(week, snapshot)
      end
    end

    def unblocked_alert(result)
      week = result.final_weeks.find do |w|
        active = w.members.reject { |m| m["paused"] }
        active.any? && active.all? { |m| m["logs_count"].to_i.positive? }
      end
      send_event Events::UnblockedAlert.new(week) if week
    end

    def level_change(change)
      inquiry = change.absence_inquiry
      return unless inquiry

      case change.reason
      when "regressed" then send_event Events::BlockedAlert.new(change, inquiry)
      when "regression_cancelled" then send_event Events::AbsenceOutcome.cancelled(inquiry, change)
      end
    end

    def paused_outcome(inquiry, pause = nil)
      pause ||= inquiry.household_member.member_pauses.overlapping(inquiry.weeks.first).first ||
        inquiry.household_member.member_pauses.overlapping(inquiry.weeks.last).first
      send_event Events::AbsenceOutcome.paused(inquiry, pause)
    end
  end
end
