class CreateLikedTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :liked_tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.boolean :liked

      t.timestamps
    end
  end
end
