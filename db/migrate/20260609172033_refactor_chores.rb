class RefactorChores < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :chores, :users
    remove_index :chores, :user_id
    rename_column :chores, :user_id, :assigned_to_id
    add_index :chores, :assigned_to_id
    add_foreign_key :chores, :users, column: :assigned_to_id

    add_column :chores, :time_required,      :integer
    add_column :chores, :due_date,           :date
    add_column :chores, :recurring_chore_id, :bigint

    add_foreign_key :chores, :recurring_chores, column: :recurring_chore_id
    add_index :chores, :recurring_chore_id
  end
end
