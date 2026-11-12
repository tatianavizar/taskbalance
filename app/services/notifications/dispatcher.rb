module Notifications
  # Turns what the weekly engine recorded into notifications. It reads the
  # engine_events outbox (EngineEvent), never a WeeklyEngine::Result, so
  # nothing is lost when a dispatch crashes:
  #
  #   Notifications::Dispatcher.deliver_pending(household, now: now)
  #
  # Each undelivered event, oldest first, is turned into zero or more
  # notification events and handed to the Notifier; only then is it marked
  # delivered. A dispatch that dies half-way leaves the rest undelivered, and
  # the next one replays them; the Notifier's dedup_key makes the replay of a
  # half-sent event send nothing twice. An event that fails is reported and
  # stays undelivered; the others go on.
  #
  # Outbox event               -> notification
  #   household_week.final       H3 weekly report, from the final report and
  #                               the level right after it (Monday 08:00);
  #                               nothing for a household of one; the
  #                               re-engagement message instead when nobody
  #                               logged anything (2+ members)
  #   member.first_empty_week     E3 alert, about that member
  #   household.unblocked         E5
  #   household.admin_unblocked   the block lifted from the back office: only
  #                               the members behind it, never naming the team
  #   absence_inquiry.opened      the absence question (E11, P5)
  #   level.changed regressed     E4 alert, block
  #   level.changed regression_cancelled   absence outcome "cancelled"
  #   absence_inquiry.resolved paused      absence outcome "paused"
  #   member_pause.declared       the dates, to everyone (every pause path)
  #   member_pause.updated        the new dates of a pause, same message
  # Anything else (provisional week, answers, other level moves) has no
  # message yet and is simply marked delivered. A caught-up week is reported
  # too; the Notifier keeps a week that came due long ago out of inboxes.
  #
  # Called by WeeklyEngineJob after each household's run, and by
  # NotificationsDispatchJob right after a pause is declared.
  class Dispatcher
    def self.deliver_pending(household, now: Time.current)
      new(household, now).deliver_pending
    end

    def initialize(household, now)
      @household = household
      @now = now
    end

    # Returns the EngineEvents delivered by this call.
    def deliver_pending
      @household.engine_events.undelivered.to_a.select do |event|
        deliver(event)
        event.mark_delivered!(@now)
        true
      rescue StandardError => e
        Rails.error.report(e, context: { household_id: @household.id, engine_event_id: event.id })
        false
      end
    end

    private

    def deliver(event)
      subject = event.subject
      return if subject.nil? # e.g. a pause withdrawn before it was announced

      case event.name
      when "household_week.final" then weekly_report(subject, event.payload)
      when "member.first_empty_week" then no_logs_alert(subject, event.payload["user_id"])
      when "household.unblocked" then send_event Events::UnblockedAlert.new(subject)
      when "household.admin_unblocked" then send_event Events::BlockLiftedAlert.new(event)
      when "absence_inquiry.opened" then send_event Events::AbsenceQuestion.new(subject)
      when "level.changed" then level_change(subject)
      when "absence_inquiry.resolved" then resolved(subject, event.payload["outcome"])
      when "member_pause.declared" then send_event Events::PauseDeclared.new(subject)
      when "member_pause.updated" then send_event Events::PauseDeclared.new(subject, updated: true)
      end
    end

    def send_event(event)
      Notifier.call(event, now: @now)
    end

    # A household of one has no balance to report: nothing is sent. A week
    # nobody logged in (2+ members) gets the re-engagement message instead of
    # the report, on the same cap slot.
    def weekly_report(household_week, payload)
      return if household_week.members.size < 2
      return send_event Events::Reengagement.new(household_week) if nobody_logged?(household_week)

      progression = payload.slice("level", "balanced_weeks_count", "blocked").presence
      send_event Events::WeeklyReport.new(household_week, progression: progression)
    end

    def nobody_logged?(household_week)
      household_week.neutral? && %w[no_mental_logs no_execution_logs].include?(household_week.neutral_reason) &&
        household_week.members.sum { |m| m["logs_count"].to_i }.zero?
    end

    def no_logs_alert(household_week, user_id)
      snapshot = household_week.member_snapshot(user_id)
      send_event Events::NoLogsAlert.new(household_week, snapshot) if snapshot
    end

    def level_change(change)
      inquiry = change.absence_inquiry
      return unless inquiry

      case change.reason
      when "regressed" then send_event Events::BlockedAlert.new(change, inquiry)
      when "regression_cancelled" then send_event Events::AbsenceOutcome.cancelled(inquiry, change)
      end
    end

    def resolved(inquiry, outcome)
      return unless outcome == "paused"

      member = inquiry.household_member
      pause = inquiry.weeks.lazy.filter_map { |week| member.member_pauses.overlapping(week).first }.first
      send_event Events::AbsenceOutcome.paused(inquiry, pause)
    end
  end
end
