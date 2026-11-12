module Notifications
  module Events
    # A chore was assigned to someone else. Only the assignee hears about it,
    # and nobody hears about assigning a chore to themselves.
    class TaskAssigned < Event
      KIND = "task_assigned".freeze

      def initialize(chore, assigned_by:)
        super(chore.household)
        @chore = chore
        @assigned_by = assigned_by
      end

      def recipients
        assignee = @chore.assigned_to
        assignee && assignee != @assigned_by ? [ assignee ] : []
      end

      def facts
        {
          "household_name" => household.name,
          "chore_name" => @chore.effective_name,
          "due_on" => @chore.due_date&.iso8601,
          "assigned_by" => person(@assigned_by)
        }
      end

      private

      # A chore handed back and forth is announced each time it changes hands.
      def key_parts = [ "chore-#{@chore.id}", "user-#{@chore.assigned_to_id}", @chore.updated_at.to_i ]
    end
  end
end
