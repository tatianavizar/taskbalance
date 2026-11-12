# The split of one week (C4, C12, B11, B14, and lot 6's Monday proposal). It
# keeps a snapshot of the assignments and of the planned shares, so that a
# validated split stays as it was until the next Monday whatever happens to
# the chores (decision D14). Validations are stored in `approvals`.
class CreateWeekPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :week_plans do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.date :week_start, null: false
      t.string :kind, null: false, default: "weekly"
      t.string :status, null: false
      # Counts a person invited but not yet in the household (D15).
      t.boolean :provisional, null: false, default: false
      t.references :proposed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :proposed_at
      t.datetime :validated_at
      t.jsonb :participants, null: false, default: []
      t.jsonb :assignments, null: false, default: []
      t.jsonb :shares, null: false, default: {}
      t.timestamps
    end
    add_index :week_plans, [ :household_id, :week_start ], unique: true
    add_check_constraint :week_plans, "status IN ('awaiting_proposal', 'proposed', 'validated')",
                         name: "week_plans_status"
    add_check_constraint :week_plans, "kind IN ('starting', 'weekly')", name: "week_plans_kind"

    # One validation per person and per thing validated (a week plan or a
    # change of the split settings). Only two states are ever shown.
    create_table :approvals do |t|
      t.references :approvable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end
    add_index :approvals, [ :approvable_type, :approvable_id, :user_id ], unique: true,
              name: "index_approvals_unique_per_user"

    create_table :split_setting_changes do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.references :proposed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.jsonb :changes_requested, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.datetime :applied_at
      t.timestamps
    end
    add_index :split_setting_changes, :household_id, unique: true, where: "status = 'pending'",
              name: "index_split_setting_changes_one_pending"
    add_check_constraint :split_setting_changes, "status IN ('pending', 'applied', 'withdrawn')",
                         name: "split_setting_changes_status"
  end
end
