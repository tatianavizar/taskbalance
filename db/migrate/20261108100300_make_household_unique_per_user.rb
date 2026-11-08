class MakeHouseholdUniquePerUser < ActiveRecord::Migration[8.0]
  # Decision of 2026-11-08: one household per account. Accounts that currently
  # sit in several households keep their OLDEST membership. The other
  # memberships are removed and the chores that were assigned to the person in
  # those households become unassigned. Their ChoreLogs are untouched (logs
  # belong to the individual). Every removal is printed.
  def up
    duplicates = select_rows(<<~SQL.squish)
      SELECT user_id FROM household_members GROUP BY user_id HAVING COUNT(*) > 1
    SQL

    duplicates.flatten.each do |user_id|
      rows = select_rows("SELECT id, household_id FROM household_members WHERE user_id = #{user_id.to_i} ORDER BY created_at, id")
      kept, *extra = rows
      extra.each do |id, household_id|
        say "user #{user_id}: keeps household #{kept[1]}, leaves household #{household_id}"
        execute "UPDATE chores SET assigned_to_id = NULL WHERE assigned_to_id = #{user_id.to_i} AND household_id = #{household_id.to_i}"
        execute "UPDATE recurring_chores SET assigned_to_id = NULL WHERE assigned_to_id = #{user_id.to_i} AND household_id = #{household_id.to_i}"
        execute "DELETE FROM household_members WHERE id = #{id.to_i}"
      end
    end

    remove_index :household_members, :user_id
    add_index :household_members, :user_id, unique: true
  end

  def down
    remove_index :household_members, :user_id
    add_index :household_members, :user_id
  end
end
