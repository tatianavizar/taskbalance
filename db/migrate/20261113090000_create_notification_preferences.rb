# One setting per event type and per person (D9). A missing row means the
# default of NotificationPreference::DEFAULTS, so existing accounts need no backfill.
class CreateNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :event_type, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :notification_preferences, [ :user_id, :event_type ], unique: true
  end
end
