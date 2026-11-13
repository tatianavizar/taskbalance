module Notifications
  module Events
    # B12 « Prêt »: the manager has chosen the household's tasks, so the
    # member who joined early and waited can see their preferences and split.
    class HouseholdReady < Event
      KIND = "household_ready".freeze

      def initialize(household, member)
        super(household)
        @member = member
      end

      def recipients = [ @member ]

      def facts
        { "household_name" => household.name }
      end

      private

      def key_parts = [ "household-#{household.id}", "user-#{@member.id}" ]
    end
  end
end
