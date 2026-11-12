# What 50/50 told a person: the in-app feed, the record of what was sent (the
# cap and idempotence rely on it) and the facts each message was written from.
class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :household, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false          # catalogue entry, e.g. "weekly_report"
      t.string :event_type, null: false    # the setting that governs it
      t.string :cap_class                  # "report" or "alert": one per person and week; nil: uncapped
      t.string :dedup_key, null: false     # one event, whoever receives it
      t.jsonb :facts, null: false, default: {} # same for every recipient (D8)
      t.string :channel                    # "email", later "push"; nil: not sent
      t.string :suppressed_reason          # "preference", "cap", "stale", "no_channel"
      t.date :cap_week_start               # local Monday of the week the cap counts it in
      t.datetime :deliver_at, null: false
      t.datetime :dispatched_at
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, [ :user_id, :dedup_key ], unique: true
    # The cap, enforced by the database: one sent report and one sent alert per person and week.
    add_index :notifications, [ :user_id, :cap_class, :cap_week_start ], unique: true,
              where: "channel IS NOT NULL AND cap_class IS NOT NULL", name: "index_notifications_weekly_cap"
    add_index :notifications, [ :user_id, :created_at ]
    add_check_constraint :notifications, "channel IS NULL OR suppressed_reason IS NULL", name: "notifications_sent_or_suppressed"
  end
end
