# Weekly reports. One row per household and local week: provisional from
# Sunday 20:00, final from Monday 03:00 (household time zone). A final row is
# never rewritten. Members and pauses are snapshotted (first name included) so
# a report stays readable after someone leaves.
class CreateHouseholdWeeks < ActiveRecord::Migration[8.0]
  def change
    create_table :household_weeks do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.date :week_start, null: false
      t.string :time_zone, null: false
      t.string :status, null: false, default: "provisional"
      t.string :outcome, null: false
      t.string :neutral_reason
      t.integer :fair_share
      t.integer :mental_total, null: false, default: 0
      t.integer :execution_total, null: false, default: 0
      t.integer :minutes_total, null: false, default: 0
      t.jsonb :members, null: false, default: []
      t.jsonb :pauses, null: false, default: []
      t.datetime :computed_at, null: false
      t.datetime :finalized_at
      t.timestamps
    end
    add_index :household_weeks, [ :household_id, :week_start ], unique: true
    add_index :household_weeks, [ :household_id, :status, :week_start ]
  end
end
