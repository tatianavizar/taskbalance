module Notifications
  module Events
    # E4: a second empty week and no answer to the absence question: the
    # household goes down one level and is blocked. The level change is the
    # engine's record of it.
    class BlockedAlert < Event
      KIND = "alert_blocked".freeze

      def initialize(level_change, inquiry)
        super(inquiry.household)
        @change = level_change
        @inquiry = inquiry
      end

      def deliver_at = [ @inquiry.deadline_at, Time.current ].max

      def facts
        subject = @inquiry.household_member.user
        {
          "household_name" => household.name,
          "subject" => person(subject),
          "from_level" => @change.from_level,
          "to_level" => @change.to_level,
          "first_week_start" => @inquiry.first_week_start.iso8601,
          "last_week_end" => (@inquiry.last_week_start + 6).iso8601,
          "weeks" => 2
        }
      end

      private

      def key_parts = [ "inquiry-#{@inquiry.id}" ]
    end
  end
end
