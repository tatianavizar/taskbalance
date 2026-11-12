# Fan-out of the weekly engine and the recurring chore scheduler.
#
# engine_due_at          next moment WeeklyEngine has something to do for the
#                        household (see WeeklyEngine#next_due_at). Defaults to
#                        now: a new household, or any row before this migration,
#                        is due.
# engine_claimed_at      set by the dispatcher when it enqueues the household, so
#                        a backlog is not enqueued twice; stale after
#                        EngineCycle::CLAIM_TTL.
# chores_scheduled_week  Monday (local) of the last week whose occurrences the
#                        scheduler wrote for the household.
# chores_claimed_at      the same claim, for the chore scheduler.
class AddEngineSchedulingToHouseholds < ActiveRecord::Migration[8.0]
  def change
    add_column :households, :engine_due_at, :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" }
    add_column :households, :engine_claimed_at, :datetime
    add_column :households, :chores_scheduled_week, :date
    add_column :households, :chores_claimed_at, :datetime

    add_index :households, :engine_due_at
    add_index :households, %i[time_zone chores_scheduled_week]
    # Households with an engine_event still to deliver, for the dispatcher.
    add_index :engine_events, :household_id, where: "delivered_at IS NULL",
              name: "index_engine_events_undelivered_by_household"
  end
end
