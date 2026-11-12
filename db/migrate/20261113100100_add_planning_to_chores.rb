# A household chore now says how often it comes back (frequency and
# times_per_period), the date it falls due for monthly, yearly and one-off
# chores (anchor_on), who created it, and whether it is still in use: a
# catalogue chore is retired, not deleted (backlog 3.4).
class AddPlanningToChores < ActiveRecord::Migration[8.0]
  def up
    add_column :chores, :frequency, :integer, null: false, default: 1
    add_column :chores, :times_per_period, :integer, null: false, default: 1
    add_column :chores, :anchor_on, :date
    add_reference :chores, :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :chores, :active, :boolean, null: false, default: true
    add_index :chores, [ :household_id, :active ]
    add_check_constraint :chores, "times_per_period >= 1", name: "chores_times_per_period_positive"

    # Catalogue chores take the frequency of their task.
    execute <<~SQL
      UPDATE chores SET frequency = tasks.frequency, times_per_period = tasks.times_per_period
      FROM tasks WHERE tasks.id = chores.task_id
    SQL
  end

  def down
    remove_check_constraint :chores, name: "chores_times_per_period_positive"
    remove_index :chores, [ :household_id, :active ]
    remove_column :chores, :active
    remove_reference :chores, :created_by, foreign_key: { to_table: :users }
    remove_column :chores, :anchor_on
    remove_column :chores, :times_per_period
    remove_column :chores, :frequency
  end
end
