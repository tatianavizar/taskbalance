class AddUniqueIndexToLikedTasks < ActiveRecord::Migration[8.0]
  def change
    add_index :liked_tasks, [:user_id, :task_id], unique: true
  end
end
