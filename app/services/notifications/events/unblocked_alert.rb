module Notifications
  module Events
    # E5: the first closed week where every active member logged something
    # lifts the block. A success message: it names no one.
    class UnblockedAlert < Event
      KIND = "alert_unblocked".freeze

      def initialize(household_week)
        super(household_week.household)
        @week = household_week
      end

      def deliver_at = monday_morning_after(@week.week)

      def facts
        {
          "household_name" => household.name,
          "week_start" => @week.week_start.iso8601,
          "week_number" => @week.week.number,
          "balanced" => @week.effective_outcome == "balanced",
          "level" => household.level,
          "next_level" => household.ultimate_level? ? nil : household.level + 1
        }
      end

      private

      def key_parts = [ "household-#{household.id}", @week.week_start.iso8601 ]
    end
  end
end
