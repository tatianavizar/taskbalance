class CreateRecurringChores < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_chores do |t|
      t.references :household,   null: false, foreign_key: true
      t.references :task,        null: false, foreign_key: true
      t.bigint     :assigned_to_id
      t.integer    :frequency,      null: false
      t.integer    :time_required
      t.boolean    :mental_load,    null: false, default: false
      t.boolean    :execution_load, null: false, default: false
      t.boolean    :active,         null: false, default: true
      t.timestamps
    end

    add_foreign_key :recurring_chores, :users, column: :assigned_to_id
    add_index :recurring_chores, [:household_id, :active]
  end
end
