# Answers to the absence question (E11, P5): every member, the absent one
# included, answers "yes" (they were away) or "no", once per inquiry, until
# the Wednesday 20:00 deadline. A "yes" declares the pause (member_pause).
# The member concerned can correct an answer made about them: the respondent's
# own word is kept in original_answer.
#
# engine_events: an outbox of what the weekly engine did (inquiry opened,
# answer given or corrected, inquiry resolved). Nothing is sent; lot 8 reads
# the undelivered rows and sets delivered_at.
class CreateAbsenceAnswersAndEngineEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :absence_answers do |t|
      t.references :absence_inquiry, null: false, foreign_key: { on_delete: :cascade }
      t.references :household_member, null: false, foreign_key: { on_delete: :cascade }
      t.string :answer, null: false
      t.datetime :answered_at, null: false
      t.references :member_pause, foreign_key: { on_delete: :nullify }
      t.string :original_answer
      t.datetime :corrected_at
      t.timestamps
    end
    add_index :absence_answers, [ :absence_inquiry_id, :household_member_id ], unique: true
    add_check_constraint :absence_answers, "answer IN ('yes', 'no')", name: "absence_answers_answer_values"

    create_table :engine_events do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.references :subject, polymorphic: true
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.datetime :delivered_at
      t.datetime :created_at, null: false
    end
    add_index :engine_events, [ :household_id, :occurred_at ]
    add_index :engine_events, :occurred_at, where: "delivered_at IS NULL", name: "index_engine_events_undelivered"
  end
end
