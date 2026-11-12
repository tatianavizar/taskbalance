# The occurrences of a chore in a local week (lot 4, D3/D4/D12/D13): what the
# Tasks tab lists as late, today and later, and what « Fait » ticks off. The
# chore says how often it comes back; RecurringChoreScheduler writes one row
# per planned occurrence, idempotently (unique chore + week + slot).
#
# An occurrence has no status: it is done for a person when a ChoreLog of that
# person points at it (chore_logs.occurrence_id). Deleting the log reopens it.
#
# The log also gets the idempotency key of the form that created it (a double
# tap makes one log) and `off_split`, snapshotted at creation: the task was
# outside the week's validated split (decision 2026-11-12, D14), or typed by
# hand without any task behind it (D6).
class CreateChoreOccurrences < ActiveRecord::Migration[8.0]
  def change
    create_table :chore_occurrences do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.references :chore, null: false, foreign_key: { on_delete: :cascade }
      t.date :week_start, null: false
      t.integer :slot, null: false
      t.date :due_on, null: false
      t.timestamps
    end
    add_index :chore_occurrences, [ :chore_id, :week_start, :slot ], unique: true,
              name: "index_chore_occurrences_unique_slot"
    add_index :chore_occurrences, [ :household_id, :due_on ]

    add_reference :chore_logs, :occurrence, foreign_key: { to_table: :chore_occurrences, on_delete: :nullify }
    add_column :chore_logs, :idempotency_key, :string
    add_column :chore_logs, :off_split, :boolean, null: false, default: false
    add_index :chore_logs, [ :user_id, :idempotency_key ], unique: true, where: "idempotency_key IS NOT NULL",
              name: "index_chore_logs_unique_idempotency_key"
  end
end
