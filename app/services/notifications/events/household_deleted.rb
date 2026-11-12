module Notifications
  module Events
    # F3: the manager deleted the household. The other members hear it (by
    # email, backlog 3.5). Sent before the household row goes: the
    # notification keeps its recipient and loses its household reference
    # (foreign key nullified), so the feed and the email job still find it.
    class HouseholdDeleted < Event
      KIND = "household_deleted".freeze

      def initialize(household, deleted_by:)
        super(household)
        @deleted_by = deleted_by
      end

      def recipients
        household.users.where.not(id: @deleted_by.id).order(:id).to_a
      end

      def facts
        { "household_name" => household.name, "deleted_by" => person(@deleted_by) }
      end

      private

      def key_parts = [ "household-#{household.id}" ]
    end
  end
end
