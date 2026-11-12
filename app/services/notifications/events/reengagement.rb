module Notifications
  module Events
    # Sent instead of the weekly report when nobody in a household of two or
    # more logged anything during the week (there is no balance to report).
    # Factual: the week, the household, what the app does, one way back. No
    # guilt, no urgency, no streak (decisions 2026-11-08, manipulation review),
    # and it names no one. It takes the weekly "report" slot, so a member never
    # gets both, and follows the weekly_report setting.
    class Reengagement < Event
      KIND = "reengagement".freeze

      def initialize(household_week)
        super(household_week.household)
        @week = household_week
      end

      def deliver_at = monday_morning_after(@week.week)

      def facts
        { "household_name" => household.name, "week_start" => @week.week_start.iso8601, "week_number" => @week.week.number }
      end

      private

      def key_parts = [ "household-#{household.id}", @week.week_start.iso8601 ]
    end
  end
end
