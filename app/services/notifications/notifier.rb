module Notifications
  # Tells people about an event. The one place that decides whether, how and
  # when each recipient is told:
  #
  #   Notifications::Notifier.call(event)                     # every recipient of the event
  #   Notifications::Notifier.call(event, to: [ user ])       # these people only
  #   Notifications::Notifier.call(event, now: some_time)
  #
  # For each recipient, in order:
  #   1. already recorded for this event (same dedup_key)? Nothing: sending
  #      the same event twice sends it once;
  #   2. the person switched this event type off? Recorded as suppressed
  #      "preference", not shown in the feed, not sent;
  #   3. the event came due long ago (Event::STALE_AFTER)? Suppressed "stale":
  #      in the feed, not sent;
  #   4. no channel reaches the person? Suppressed "no_channel";
  #   5. the cap (D9): one report and one alert per week and per person, all
  #      channels together. Over the cap: suppressed "cap", in the feed;
  #   6. otherwise handed to the first available channel (Channels.for).
  # Every case leaves a Notification row, which is what makes 1 and 5 work.
  #
  # Returns the Notification rows, in recipient order.
  class Notifier
    def self.call(event, to: nil, now: Time.current)
      new(event, now: now).call(to: to)
    end

    def initialize(event, now: Time.current)
      @event = event
      @now = now
    end

    def call(to: nil)
      facts = @event.facts
      Array(to || @event.recipients).uniq.map { |user| notify(user, facts) }
    end

    private

    attr_reader :event

    def notify(user, facts)
      existing = Notification.find_by(user_id: user.id, dedup_key: event.dedup_key)
      return existing if existing

      reason = suppression(user)
      channel = reason ? nil : Channels.for(user)
      reason ||= "no_channel" unless channel

      record = create_record(user, facts, channel: (channel::NAME if channel), reason: reason)
      return record unless record.sent?

      channel.new.deliver(record)
      record.update_columns(dispatched_at: @now)
      record
    rescue ActiveRecord::RecordNotUnique
      # A parallel run recorded the same event first.
      Notification.find_by!(user_id: user.id, dedup_key: event.dedup_key)
    end

    def suppression(user)
      unless Catalogue.transactional?(event.kind) || NotificationPreference.enabled?(user, event.event_type)
        return "preference"
      end
      return "stale" if @now > event.deliver_at + Event::STALE_AFTER

      nil
    end

    # Writes the row. The partial unique index on (user, cap_class, week) is
    # the cap itself: when another sent notification already holds the slot,
    # the row is written again as suppressed "cap".
    def create_record(user, facts, channel:, reason:)
      return insert(user, facts, channel: channel, reason: reason) unless channel && event.cap_class
      return insert(user, facts, channel: nil, reason: "cap") if cap_taken?(user)

      begin
        Notification.transaction(requires_new: true) { insert(user, facts, channel: channel, reason: nil) }
      rescue ActiveRecord::RecordNotUnique
        raise if Notification.exists?(user_id: user.id, dedup_key: event.dedup_key)

        insert(user, facts, channel: nil, reason: "cap")
      end
    end

    def insert(user, facts, channel:, reason:)
      Notification.create!(
        user: user, household: event.household, kind: event.kind, event_type: event.event_type,
        cap_class: event.cap_class, dedup_key: event.dedup_key, facts: facts, channel: channel,
        suppressed_reason: reason, cap_week_start: cap_week_start, deliver_at: event.deliver_at
      )
    end

    def cap_taken?(user)
      Notification.sent.exists?(user_id: user.id, cap_class: event.cap_class, cap_week_start: cap_week_start)
    end

    # The local week the message goes out in, in the household's zone.
    def cap_week_start
      @cap_week_start ||= event.household.week_containing(event.deliver_at).monday
    end
  end
end
