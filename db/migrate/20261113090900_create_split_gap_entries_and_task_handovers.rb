# Lot 6 (backlog 2.2c).
#
# split_gap_entries: the carried-over gap, as a ledger. A member's balance is
# the sum of their entries, in percent of the fair share (positive: they
# carried more than their share). `week` entries add the real gap of a
# closed week (average of the two charges, from the final HouseholdWeek);
# `reset` entries bring balances back to zero (C9, D4).
# households.gap_folded_through: the last closed week already folded in.
#
# week_plans.targets: what the Monday proposal aimed at for each participant
# (fair share minus their balance, kept inside the zone). carry_gap false:
# the member who carried the surplus saved an out-of-zone split without
# carrying its gap (decision 2026-11-08); that week is not folded in.
#
# task_handovers: one-off reassignment (D15, D16). A member offers one of
# their tasks to another for one week; the validated plan does not change.
class CreateSplitGapEntriesAndTaskHandovers < ActiveRecord::Migration[8.0]
  def change
    create_table :split_gap_entries do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.date :week_start, null: false
      t.decimal :amount, precision: 8, scale: 3, null: false
      t.references :reset_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :created_at, null: false
    end
    add_index :split_gap_entries, [ :household_id, :user_id ]
    add_check_constraint :split_gap_entries, "kind IN ('week', 'reset')", name: "split_gap_entries_kind"

    add_column :households, :gap_folded_through, :date

    change_table :week_plans, bulk: true do |t|
      t.jsonb :targets, null: false, default: {}
      t.boolean :carry_gap, null: false, default: true
      t.references :gap_waived_by, foreign_key: { to_table: :users, on_delete: :nullify }
    end

    create_table :task_handovers do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.references :chore, null: false, foreign_key: { on_delete: :cascade }
      t.references :from_user, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :to_user, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.date :week_start, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :responded_at
      t.timestamps
    end
    add_index :task_handovers, [ :chore_id, :week_start, :from_user_id ], unique: true,
              where: "status IN ('pending', 'accepted')", name: "index_task_handovers_live"
    add_check_constraint :task_handovers, "status IN ('pending', 'accepted', 'refused', 'cancelled')",
                         name: "task_handovers_status"
    add_check_constraint :task_handovers, "from_user_id <> to_user_id", name: "task_handovers_two_people"
  end
end
