module Notifications
  module Events
    # A pause was declared for a member, by themselves or by someone else
    # (docs/backend-backlog.md 2.3: "Notify every member of the dates"). The
    # reason is private and never part of the facts.
    class PauseDeclared < Event
      KIND = "pause_declared".freeze

      def initialize(pause, updated: false)
        super(pause.household)
        @pause = pause
        @updated = updated
      end

      def facts
        {
          "household_name" => household.name,
          "subject" => person(@pause.household_member.user),
          "starts_on" => @pause.starts_on.iso8601,
          "ends_on" => @pause.ends_on&.iso8601
        }
      end

      private

      # New dates of the same pause are a new occurrence, sent again.
      def key_parts = @updated ? [ "pause-#{@pause.id}", "dates-#{@pause.starts_on}-#{@pause.ends_on}" ] : [ "pause-#{@pause.id}" ]
    end
  end
end
