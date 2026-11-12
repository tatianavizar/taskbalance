# Preferences have three choices (J'aime, Neutre, Je n'aime pas) and are given
# per household chore, custom chores included (B10, C3, P7). They are private
# to their author. Replaces liked_tasks: each row is carried over to the
# chores of the author's household that use the task.
class ReplaceLikedTasksWithChorePreferences < ActiveRecord::Migration[8.0]
  def up
    create_table :chore_preferences do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :chore, null: false, foreign_key: { on_delete: :cascade }
      t.string :choice, null: false
      t.timestamps
    end
    add_index :chore_preferences, [ :user_id, :chore_id ], unique: true
    add_check_constraint :chore_preferences, "choice IN ('like', 'neutral', 'dislike')",
                         name: "chore_preferences_choice"

    execute <<~SQL
      INSERT INTO chore_preferences (user_id, chore_id, choice, created_at, updated_at)
      SELECT DISTINCT ON (liked_tasks.user_id, chores.id)
             liked_tasks.user_id, chores.id,
             CASE WHEN liked_tasks.liked THEN 'like' ELSE 'dislike' END,
             liked_tasks.created_at, liked_tasks.updated_at
      FROM liked_tasks
      JOIN household_members ON household_members.user_id = liked_tasks.user_id
      JOIN chores ON chores.household_id = household_members.household_id
                 AND chores.task_id = liked_tasks.task_id
      WHERE liked_tasks.liked IS NOT NULL
      ORDER BY liked_tasks.user_id, chores.id
    SQL

    drop_table :liked_tasks
  end

  def down
    create_table :liked_tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.boolean :liked
      t.timestamps
    end
    add_index :liked_tasks, [ :user_id, :task_id ], unique: true

    execute <<~SQL
      INSERT INTO liked_tasks (user_id, task_id, liked, created_at, updated_at)
      SELECT DISTINCT ON (chore_preferences.user_id, chores.task_id)
             chore_preferences.user_id, chores.task_id, chore_preferences.choice = 'like',
             chore_preferences.created_at, chore_preferences.updated_at
      FROM chore_preferences JOIN chores ON chores.id = chore_preferences.chore_id
      WHERE chores.task_id IS NOT NULL AND chore_preferences.choice <> 'neutral'
      ORDER BY chore_preferences.user_id, chores.task_id
    SQL

    drop_table :chore_preferences
  end
end
