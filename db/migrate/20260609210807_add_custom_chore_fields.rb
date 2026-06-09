class AddCustomChoreFields < ActiveRecord::Migration[8.0]
  def change
    # Make task_id nullable — custom chores don't reference the catalogue
    change_column_null :chores, :task_id, true
    remove_foreign_key :chores, :tasks
    add_foreign_key :chores, :tasks, on_delete: :restrict, validate: false

    add_column :chores, :custom_name, :string
    add_column :chores, :category, :string
  end
end
