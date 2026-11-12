module Notifications
  module Events
    # The back office lifted a household's block (BackOffice::Actions,
    # decision of 2026-11-13). Only the members whose empty weeks caused it
    # hear about it (`user_ids` of the household.admin_unblocked event); the
    # rest of the household is not told, and the message never says who
    # lifted it.
    class BlockLiftedAlert < Event
      KIND = "alert_block_lifted".freeze

      def initialize(engine_event)
        super(engine_event.household)
        @engine_event = engine_event
      end

      def recipients
        ids = Array(@engine_event.payload["user_ids"])
        household.users.where(id: ids).order(:id).to_a
      end

      def facts
        { "household_name" => household.name, "level" => @engine_event.payload["level"] }
      end

      private

      def key_parts = [ "household-#{household.id}", "event-#{@engine_event.id}" ]
    end
  end
end
