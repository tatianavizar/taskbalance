# Logs belong to the individual, not to the household (see CLAUDE.md, "Data
# ownership rule"). Before this migration, chore_logs.chore_id and
# household_id were NOT NULL with a restricting foreign key, so deleting a
# household cascaded into its members' logs and destroyed them.
#
# After it, a log outlives both its chore and its household: the references
# are nullified and the chore's name and category are snapshotted onto the
# log so it stays meaningful once detached.
class DecoupleChoreLogsFromChoresAndHouseholds < ActiveRecord::Migration[8.0]
  def up
    add_column :chore_logs, :chore_name, :string
    add_column :chore_logs, :category, :string

    # Snapshot existing logs from the chore (and its task, for catalogue chores).
    execute <<~SQL
      UPDATE chore_logs AS cl
         SET chore_name = COALESCE(t.name, c.custom_name),
             category   = COALESCE(t.category, c.category)
        FROM chores AS c
        LEFT JOIN tasks AS t ON t.id = c.task_id
       WHERE cl.chore_id = c.id
    SQL

    change_column_null :chore_logs, :chore_id, true
    change_column_null :chore_logs, :household_id, true

    # Re-point the chores FK at ON DELETE SET NULL so destroying a chore
    # detaches its logs instead of deleting them.
    remove_foreign_key :chore_logs, :chores
    add_foreign_key :chore_logs, :chores, on_delete: :nullify

    # household_id never had a foreign key, so orphans are possible. Clear
    # them before adding the constraint, then protect it the same way.
    execute <<~SQL
      UPDATE chore_logs
         SET household_id = NULL
       WHERE household_id IS NOT NULL
         AND household_id NOT IN (SELECT id FROM households)
    SQL
    add_foreign_key :chore_logs, :households, on_delete: :nullify
  end

  def down
    remove_foreign_key :chore_logs, :households
    remove_foreign_key :chore_logs, :chores
    add_foreign_key :chore_logs, :chores

    # Rows detached from a chore or household cannot satisfy the old NOT NULL
    # constraints, and their originals are gone. Dropping them is the only way
    # back, which is why this migration is effectively one-way in production.
    execute "DELETE FROM chore_logs WHERE chore_id IS NULL OR household_id IS NULL"

    change_column_null :chore_logs, :chore_id, false
    change_column_null :chore_logs, :household_id, false

    remove_column :chore_logs, :category
    remove_column :chore_logs, :chore_name
  end
end
