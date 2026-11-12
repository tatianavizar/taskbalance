module Notifications
  module Events
    # Monday: the proposed split of the week's tasks is ready (backlog 2.4,
    # D11). Same figures for everyone: how many tasks each member has.
    class MondaySplit < Event
      KIND = "monday_split".freeze

      # `counts`: { user => number of tasks planned this week }.
      def initialize(household, week, counts)
        super(household)
        @week = week
        @counts = counts
      end

      def deliver_at = household.zone.local(@week.monday.year, @week.monday.month, @week.monday.day, 8)

      def facts
        {
          "household_name" => household.name,
          "week_start" => @week.monday.iso8601,
          "week_number" => @week.number,
          "counts" => @counts.map { |user, tasks| person(user).merge("tasks" => tasks) }
        }
      end

      private

      def key_parts = [ "household-#{household.id}", @week.monday.iso8601 ]
    end
  end
end
