# Several members can carry one chore (backlog 2.2d, decision D6): one row per
# assignee, each carrying the chore in full. Replaces chores.assigned_to_id.
#
# An assignee is a member (user_id) or, for the starting split only, a person
# invited but not yet in the household (invitation_id, decision D15). Lot 3
# moves those rows to the user when the invitation is accepted
# (ChoreAssignee.transfer_invitation!).
class CreateChoreAssignees < ActiveRecord::Migration[8.0]
  def up
    create_table :chore_assignees do |t|
      t.references :chore, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :cascade }
      t.references :invitation, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end
    add_check_constraint :chore_assignees, "num_nonnulls(user_id, invitation_id) = 1",
                         name: "chore_assignees_one_assignee"
    add_index :chore_assignees, [ :chore_id, :user_id ], unique: true, where: "user_id IS NOT NULL",
              name: "index_chore_assignees_unique_user"
    add_index :chore_assignees, [ :chore_id, :invitation_id ], unique: true, where: "invitation_id IS NOT NULL",
              name: "index_chore_assignees_unique_invitation"

    # The former single assignee keeps the chore.
    execute <<~SQL
      INSERT INTO chore_assignees (chore_id, user_id, created_at)
      SELECT id, assigned_to_id, NOW() FROM chores WHERE assigned_to_id IS NOT NULL
    SQL
    # A chore nobody carried goes to every member ("Tout le foyer", D6), so
    # every chore has at least one assignee. The next proposal can change it.
    execute <<~SQL
      INSERT INTO chore_assignees (chore_id, user_id, created_at)
      SELECT chores.id, household_members.user_id, NOW()
      FROM chores JOIN household_members ON household_members.household_id = chores.household_id
      WHERE chores.assigned_to_id IS NULL
    SQL

    remove_reference :chores, :assigned_to, foreign_key: { to_table: :users }, index: true
  end

  def down
    add_reference :chores, :assigned_to, foreign_key: { to_table: :users }, index: true
    execute <<~SQL
      UPDATE chores SET assigned_to_id = sub.user_id
      FROM (SELECT chore_id, MIN(user_id) AS user_id FROM chore_assignees
            WHERE user_id IS NOT NULL GROUP BY chore_id) sub
      WHERE sub.chore_id = chores.id
    SQL
    drop_table :chore_assignees
  end
end
