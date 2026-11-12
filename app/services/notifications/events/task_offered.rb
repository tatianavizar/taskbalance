module Notifications
  module Events
    # D15: a member offers one of their tasks to another for this week only.
    # Only the person offered the task hears about it.
    class TaskOffered < Event
      KIND = "task_offered".freeze

      def initialize(handover)
        super(handover.household)
        @handover = handover
      end

      def recipients = [ @handover.to_user ]

      def facts
        {
          "household_name" => household.name,
          "chore_name" => @handover.chore.effective_name,
          "week_number" => @handover.week.number,
          "offered_by" => person(@handover.from_user),
          "handover_id" => @handover.id
        }
      end

      private

      def key_parts = [ "handover-#{@handover.id}" ]
    end
  end
end
