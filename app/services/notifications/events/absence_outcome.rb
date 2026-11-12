module Notifications
  module Events
    # What became of an absence question, when it did not end in a regression
    # (that one is the E4 alert):
    #   paused     a pause covers the two empty weeks: no level lost;
    #   cancelled  a pause declared afterwards cancelled a regression (D3): the
    #              level and the counter are back, the block is lifted.
    # Names the member concerned and no one else: it is a result, not a credit.
    class AbsenceOutcome < Event
      KIND = "absence_outcome".freeze
      OUTCOMES = %w[paused cancelled].freeze

      def self.paused(inquiry, pause) = new(inquiry, "paused", pause: pause)
      def self.cancelled(inquiry, level_change) = new(inquiry, "cancelled", level_change: level_change)

      def initialize(inquiry, outcome, pause: nil, level_change: nil)
        raise ArgumentError, "unknown outcome #{outcome}" unless OUTCOMES.include?(outcome)

        super(inquiry.household)
        @inquiry = inquiry
        @outcome = outcome
        @pause = pause
        @level_change = level_change
      end

      def facts
        {
          "household_name" => household.name,
          "outcome" => @outcome,
          "subject" => person(@inquiry.household_member.user),
          "starts_on" => (@pause&.starts_on || @inquiry.first_week_start).iso8601,
          "ends_on" => (@pause ? @pause.ends_on : @inquiry.last_week_start + 6)&.iso8601,
          "level" => household.level
        }
      end

      private

      def key_parts = [ @outcome, "inquiry-#{@inquiry.id}" ]
    end
  end
end
