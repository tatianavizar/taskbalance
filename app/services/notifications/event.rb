module Notifications
  # Something that happened in a household and that some people should hear
  # about. An event knows what happened and to whom to tell it; it never
  # decides whether, how or when a given person is told: that is the Notifier.
  #
  # A subclass sets KIND and defines:
  #   facts         JSON-friendly Hash (string keys), the same for every
  #                 recipient (D8). All figures live here; phrasing is added at
  #                 render time, per recipient (Notifications::Message).
  #   key_parts     what makes this occurrence unique (week, inquiry...), so
  #                 running the same event twice sends it once.
  # and may override `recipients` (default: every member) and `deliver_at`.
  class Event
    # An event that came due this long ago is recorded in the feed but not
    # sent: a worker that was down for days must not flood inboxes.
    STALE_AFTER = 2.days

    attr_reader :household

    def initialize(household)
      @household = household
    end

    def kind = self.class::KIND
    def entry = Catalogue.fetch(kind)
    def event_type = entry.event_type
    def cap_class = entry.cap
    def target = entry.target

    def recipients
      household.users.order(:id).to_a
    end

    # When the person should get it. The engine closes a week at Monday 03:00
    # and the messages go out at 08:00 (backlog, "Decisions wait for the close").
    def deliver_at
      Time.current
    end

    def dedup_key
      [ kind, *key_parts ].join(":")
    end

    private

    # Monday 08:00 after `week`, in the household zone.
    def monday_morning_after(week)
      monday = week.next.monday
      household.zone.local(monday.year, monday.month, monday.day, 8)
    end

    # Fixed shape for who an event is about, so the text can say « vous » to
    # that person and the first name to everyone else.
    def person(user)
      { "user_id" => user.id, "first_name" => user.first_name }
    end
  end
end
