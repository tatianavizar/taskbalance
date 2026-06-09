class CreateChoreLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :chore_logs do |t|
      t.references :chore,        null: false, foreign_key: true
      t.bigint     :household_id, null: false
      t.references :user,         null: false, foreign_key: true
      t.boolean    :mental_load,    null: false
      t.boolean    :execution_load, null: false
      t.integer    :time_spent,   null: false
      t.datetime   :completed_at, null: false
    end

    add_index :chore_logs, [:household_id, :completed_at]
    add_index :chore_logs, [:user_id, :completed_at]
  end
end
