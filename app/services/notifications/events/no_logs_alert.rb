module Notifications
  module Events
    # E3: a member logged nothing during a closed week. To every member, the
    # same facts (D8). The alert asks nothing of the people who carried the
    # week: it states the figures and, for the member concerned, points to the
    # pause.
    class NoLogsAlert < Event
      KIND = "alert_no_logs".freeze
      RECENT_WEEKS = 4

      # `snapshot`: the member's entry in household_week.members.
      def initialize(household_week, snapshot)
        super(household_week.household)
        @week = household_week
        @snapshot = snapshot
      end

      def deliver_at = monday_morning_after(@week.week)

      def facts
        {
          "household_name" => household.name,
          "subject" => { "user_id" => @snapshot["user_id"], "first_name" => @snapshot["first_name"] },
          "week_start" => @week.week_start.iso8601,
          "week_number" => @week.week.number,
          "week_end" => @week.week.sunday.iso8601,
          "counts" => @week.members.reject { |m| m["paused"] }.map { |m| m.slice("user_id", "first_name", "logs_count") },
          "recent" => recent
        }
      end

      private

      def key_parts = [ "household-#{household.id}", @week.week_start.iso8601, "user-#{@snapshot["user_id"]}" ]

      # The member's own count over the last weeks, oldest first, this one last.
      def recent
        earlier = household.household_weeks.final.where(week_start: ...@week.week_start)
          .order(week_start: :desc).limit(RECENT_WEEKS - 1).to_a.reverse
        (earlier + [ @week ]).filter_map do |week|
          mine = week.member_snapshot(@snapshot["user_id"])
          next unless mine

          { "week_number" => week.week.number, "week_start" => week.week_start.iso8601, "logs_count" => mine["logs_count"].to_i }
        end
      end
    end
  end
end
