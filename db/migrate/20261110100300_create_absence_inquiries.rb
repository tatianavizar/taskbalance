# Opened when a member reaches 2 consecutive empty final weeks. The regression
# and block apply at deadline_at (Wednesday 20:00, household zone) unless a
# pause covering those weeks was declared by then. The answers themselves
# (absence_answers, the Wednesday reminder, screens E11/P5) are lot 5b.
class CreateAbsenceInquiries < ActiveRecord::Migration[8.0]
  def change
    create_table :absence_inquiries do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.references :household_member, null: false, foreign_key: { on_delete: :cascade }
      t.date :first_week_start, null: false
      t.date :last_week_start, null: false
      t.datetime :deadline_at, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :absence_inquiries, [ :household_member_id, :last_week_start ], unique: true
    add_index :absence_inquiries, [ :status, :deadline_at ]
  end
end
