# Catalogue defaults (lot 2): each task gets a stable key, the loads it
# usually carries, and how often it comes back. The key lets the seeds
# translate or rename a task without losing the chores that point to it.
class AddDefaultsAndKeyToTasks < ActiveRecord::Migration[8.0]
  class MigrationTask < ActiveRecord::Base
    self.table_name = "tasks"
  end

  def up
    add_column :tasks, :key, :string
    add_column :tasks, :default_mental_load, :boolean, null: false, default: false
    add_column :tasks, :default_execution_load, :boolean, null: false, default: false
    # Same integers as Chore#frequency: daily 0, weekly 1, monthly 2, annually 3, once 4.
    add_column :tasks, :frequency, :integer, null: false, default: 1
    add_column :tasks, :times_per_period, :integer, null: false, default: 1

    MigrationTask.reset_column_information
    taken = Set.new
    MigrationTask.order(:id).each do |task|
      base = task.name.to_s.parameterize(separator: "_").presence || "task"
      key = taken.include?(base) ? "#{base}_#{task.id}" : base
      taken << key
      task.update_columns(key: key)
    end

    change_column_null :tasks, :key, false
    add_index :tasks, :key, unique: true
    add_check_constraint :tasks, "times_per_period >= 1", name: "tasks_times_per_period_positive"
  end

  def down
    remove_check_constraint :tasks, name: "tasks_times_per_period_positive"
    remove_index :tasks, :key
    remove_column :tasks, :times_per_period
    remove_column :tasks, :frequency
    remove_column :tasks, :default_execution_load
    remove_column :tasks, :default_mental_load
    remove_column :tasks, :key
  end
end
