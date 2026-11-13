module Notifications
  module Events
    # D16: the person offered a task accepted or refused it. Only the member
    # who offered it hears about it.
    class TaskOfferAnswered < Event
      KIND = "task_offer_answered".freeze

      def initialize(handover)
        super(handover.household)
        @handover = handover
      end

      def recipients = [ @handover.from_user ]

      def facts
        {
          "household_name" => household.name,
          "chore_name" => @handover.chore.effective_name,
          "week_number" => @handover.week.number,
          "answered_by" => person(@handover.to_user),
          "accepted" => @handover.accepted?
        }
      end

      private

      def key_parts = [ "handover-#{@handover.id}", @handover.status ]
    end
  end
end
