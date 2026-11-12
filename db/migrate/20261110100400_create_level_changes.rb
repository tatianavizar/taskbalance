# History of every level move: reached, regressed, ultimate lost or regained.
class CreateLevelChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :level_changes do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.references :household_week, foreign_key: { on_delete: :nullify }
      t.references :absence_inquiry, foreign_key: { on_delete: :nullify }
      t.integer :from_level, null: false
      t.integer :to_level, null: false
      t.integer :balanced_weeks_count_before, null: false
      t.integer :balanced_weeks_count_after, null: false
      t.string :reason, null: false
      t.date :week_start
      t.datetime :created_at, null: false
    end
  end
end
