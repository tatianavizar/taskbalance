module Notifications
  module Events
    # H3: the Sunday 20:00 report, provisional, to every member. The figures
    # are read from the stored HouseholdWeek, so every member gets the same.
    class WeeklyReport < Event
      KIND = "weekly_report".freeze
      HISTORY_WEEKS = 4

      def initialize(household_week)
        super(household_week.household)
        @week = household_week
      end

      def deliver_at = HouseholdWeek.provisional_at(@week.week)

      def facts
        members = @week.members.map { |m| member_facts(m) }
        {
          "household_name" => household.name,
          "week_start" => @week.week_start.iso8601,
          "week_number" => @week.week.number,
          "provisional" => @week.provisional?,
          "outcome" => @week.effective_outcome,
          "neutral_reason" => @week.effective_neutral_reason,
          "fair_share" => @week.fair_share,
          "zone_min" => zone&.min,
          "zone_max" => zone&.max,
          "members" => members,
          "carrier" => carrier(members),
          "level" => household.level,
          "ultimate" => household.ultimate_level?,
          "blocked" => household.blocked?,
          "weeks_to_next_level" => weeks_to_next_level,
          "previous_unbalanced" => previous_unbalanced,
          "history" => history(members)
        }
      end

      private

      def key_parts = [ "household-#{household.id}", @week.week_start.iso8601 ]

      def zone
        HouseholdRules.zone(@week.members.count { |m| !m["paused"] }) if @week.fair_share
      end

      def member_facts(m)
        m.slice("user_id", "first_name", "mental_share", "execution_share", "mental_count",
                "execution_count", "minutes", "logs_count", "paused", "in_zone_mental", "in_zone_execution")
      end

      # The member who carries more, on the dimension that tips the week. An
      # imbalance names who carries more (D8): above the zone first, the
      # largest share if nobody is above it.
      def carrier(members)
        return nil unless @week.unbalanced?

        entries = members.reject { |m| m["paused"] }.flat_map do |m|
          %w[mental execution].filter_map do |dimension|
            share = m["#{dimension}_share"]
            next if share.nil? || m["in_zone_#{dimension}"]

            { "user_id" => m["user_id"], "first_name" => m["first_name"], "dimension" => dimension, "share" => share }
          end
        end
        above = entries.select { |e| zone && e["share"] > zone.max }
        (above.presence || entries).max_by { |e| [ e["share"], e["dimension"] == "mental" ? 1 : 0 ] }
      end

      def weeks_to_next_level
        return nil if household.ultimate_level?

        [ Progression.threshold(household.level + 1) - household.balanced_weeks_count, 0 ].max
      end

      def previous_unbalanced
        count = 0
        previous_weeks.each do |week|
          break unless week.effective_outcome == "unbalanced"

          count += 1
        end
        count
      end

      # Up to HISTORY_WEEKS weeks, oldest first, the current one last: the share
      # of the member who carried the most mental load.
      def history(members)
        weeks = previous_weeks.first(HISTORY_WEEKS - 1).reverse.map { |w| [ w, w.members ] }
        weeks << [ @week, members ]
        weeks.filter_map do |week, list|
          share = list.reject { |m| m["paused"] }.filter_map { |m| m["mental_share"] }.max
          next if share.nil?

          { "week_number" => week.week.number, "share" => share, "balanced" => week.effective_outcome == "balanced" }
        end
      end

      def previous_weeks
        @previous_weeks ||= household.household_weeks.final.where(week_start: ...@week.week_start)
          .order(week_start: :desc).includes(:week_corrections).to_a
      end
    end
  end
end
