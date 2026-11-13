# Household progression (levels 0-5, 5 = ultimate), the cumulative balanced
# weeks counter and the state machine, plus each member's empty-week streak.
class AddEngineStateToHouseholds < ActiveRecord::Migration[8.0]
  def up
    change_table :households, bulk: true do |t|
      t.integer :level, null: false, default: 0
      t.integer :balanced_weeks_count, null: false, default: 0
      t.string :state, null: false, default: "solo"
      t.integer :silent_weeks_count, null: false, default: 0
      t.datetime :blocked_at
    end
    add_column :household_members, :empty_weeks_streak, :integer, null: false, default: 0

    execute <<~SQL
      UPDATE households SET state = 'active'
      WHERE (SELECT count(*) FROM household_members m WHERE m.household_id = households.id) >= 2
    SQL
  end

  def down
    remove_column :household_members, :empty_weeks_streak
    change_table :households, bulk: true do |t|
      t.remove :level, :balanced_weeks_count, :state, :silent_weeks_count, :blocked_at
    end
  end
end
