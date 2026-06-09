class AddRecurringToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :recurring, :boolean, default: false, null: false
  end
end
