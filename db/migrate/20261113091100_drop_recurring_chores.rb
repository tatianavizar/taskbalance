# Lot 4: a chore carries its own recurrence (Chore#frequency, times_per_period,
# anchor_on) and RecurringChoreScheduler reads it. The legacy template table
# and the link from chores to it are gone.
class DropRecurringChores < ActiveRecord::Migration[8.0]
  def up
    remove_reference :chores, :recurring_chore, foreign_key: true, index: true
    drop_table :recurring_chores
  end

  def down
    create_table :recurring_chores do |t|
      t.references :household, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.integer :frequency, null: false
      t.integer :time_required
      t.boolean :mental_load, null: false, default: false
      t.boolean :execution_load, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :recurring_chores, [ :household_id, :active ]
    add_reference :chores, :recurring_chore, foreign_key: true, index: true
  end
end
