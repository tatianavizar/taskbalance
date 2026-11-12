# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_11_13_090100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "absence_answers", force: :cascade do |t|
    t.bigint "absence_inquiry_id", null: false
    t.bigint "household_member_id", null: false
    t.string "answer", null: false
    t.datetime "answered_at", null: false
    t.bigint "member_pause_id"
    t.string "original_answer"
    t.datetime "corrected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["absence_inquiry_id", "household_member_id"], name: "idx_on_absence_inquiry_id_household_member_id_d7a225158d", unique: true
    t.index ["absence_inquiry_id"], name: "index_absence_answers_on_absence_inquiry_id"
    t.index ["household_member_id"], name: "index_absence_answers_on_household_member_id"
    t.index ["member_pause_id"], name: "index_absence_answers_on_member_pause_id"
    t.check_constraint "answer::text = ANY (ARRAY['yes'::character varying, 'no'::character varying]::text[])", name: "absence_answers_answer_values"
  end

  create_table "absence_inquiries", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.bigint "household_member_id", null: false
    t.date "first_week_start", null: false
    t.date "last_week_start", null: false
    t.datetime "deadline_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_absence_inquiries_on_household_id"
    t.index ["household_member_id", "last_week_start"], name: "idx_on_household_member_id_last_week_start_004aa25e77", unique: true
    t.index ["household_member_id"], name: "index_absence_inquiries_on_household_member_id"
    t.index ["status", "deadline_at"], name: "index_absence_inquiries_on_status_and_deadline_at"
  end

  create_table "chore_logs", force: :cascade do |t|
    t.bigint "chore_id"
    t.bigint "household_id"
    t.bigint "user_id", null: false
    t.boolean "mental_load", null: false
    t.boolean "execution_load", null: false
    t.integer "time_spent", null: false
    t.datetime "completed_at", null: false
    t.string "chore_name"
    t.string "category"
    t.index ["chore_id"], name: "index_chore_logs_on_chore_id"
    t.index ["household_id", "completed_at"], name: "index_chore_logs_on_household_id_and_completed_at"
    t.index ["user_id", "completed_at"], name: "index_chore_logs_on_user_id_and_completed_at"
    t.index ["user_id"], name: "index_chore_logs_on_user_id"
  end

  create_table "chores", force: :cascade do |t|
    t.bigint "task_id"
    t.bigint "household_id", null: false
    t.bigint "assigned_to_id"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "mental_load", default: false, null: false
    t.boolean "execution_load", default: false, null: false
    t.integer "time_required"
    t.date "due_date"
    t.bigint "recurring_chore_id"
    t.string "custom_name"
    t.string "category"
    t.index ["assigned_to_id"], name: "index_chores_on_assigned_to_id"
    t.index ["household_id"], name: "index_chores_on_household_id"
    t.index ["recurring_chore_id"], name: "index_chores_on_recurring_chore_id"
    t.index ["task_id"], name: "index_chores_on_task_id"
  end

  create_table "engine_events", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.string "name", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.jsonb "payload", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.index ["household_id", "occurred_at"], name: "index_engine_events_on_household_id_and_occurred_at"
    t.index ["household_id"], name: "index_engine_events_on_household_id"
    t.index ["occurred_at"], name: "index_engine_events_undelivered", where: "(delivered_at IS NULL)"
    t.index ["subject_type", "subject_id"], name: "index_engine_events_on_subject"
  end

  create_table "household_members", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "household_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "color"
    t.string "monogram"
    t.boolean "monogram_customized", default: false, null: false
    t.integer "empty_weeks_streak", default: 0, null: false
    t.index ["household_id", "color"], name: "index_household_members_on_household_id_and_color", unique: true
    t.index ["household_id"], name: "index_household_members_on_household_id"
    t.index ["user_id"], name: "index_household_members_on_user_id", unique: true
  end

  create_table "household_weeks", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.date "week_start", null: false
    t.string "time_zone", null: false
    t.string "status", default: "provisional", null: false
    t.string "outcome", null: false
    t.string "neutral_reason"
    t.integer "fair_share"
    t.integer "mental_total", default: 0, null: false
    t.integer "execution_total", default: 0, null: false
    t.integer "minutes_total", default: 0, null: false
    t.jsonb "members", default: [], null: false
    t.jsonb "pauses", default: [], null: false
    t.datetime "computed_at", null: false
    t.datetime "finalized_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "status", "week_start"], name: "idx_on_household_id_status_week_start_25d1d7005e"
    t.index ["household_id", "week_start"], name: "index_household_weeks_on_household_id_and_week_start", unique: true
    t.index ["household_id"], name: "index_household_weeks_on_household_id"
  end

  create_table "households", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone", default: "Europe/Paris", null: false
    t.integer "level", default: 0, null: false
    t.integer "balanced_weeks_count", default: 0, null: false
    t.string "state", default: "solo", null: false
    t.integer "silent_weeks_count", default: 0, null: false
    t.datetime "blocked_at"
    t.date "ultimate_reached_on"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email", null: false
    t.bigint "household_id", null: false
    t.string "token", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "state", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_sent_at", null: false
    t.integer "resend_count", default: 0, null: false
    t.datetime "accepted_at"
    t.datetime "declined_at"
    t.datetime "cancelled_at"
    t.bigint "invitee_id"
    t.bigint "inviter_id"
    t.index ["email", "household_id"], name: "index_invitations_pending_on_email_and_household_id", unique: true, where: "((state)::text = 'pending'::text)"
    t.index ["household_id", "email"], name: "index_invitations_on_household_id_and_email"
    t.index ["invitee_id"], name: "index_invitations_on_invitee_id"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "level_changes", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.bigint "household_week_id"
    t.bigint "absence_inquiry_id"
    t.integer "from_level", null: false
    t.integer "to_level", null: false
    t.integer "balanced_weeks_count_before", null: false
    t.integer "balanced_weeks_count_after", null: false
    t.string "reason", null: false
    t.date "week_start"
    t.datetime "created_at", null: false
    t.bigint "cancelled_level_change_id"
    t.index ["absence_inquiry_id"], name: "index_level_changes_on_absence_inquiry_id"
    t.index ["cancelled_level_change_id"], name: "index_level_changes_on_cancelled_level_change_id"
    t.index ["household_id"], name: "index_level_changes_on_household_id"
    t.index ["household_week_id"], name: "index_level_changes_on_household_week_id"
  end

  create_table "liked_tasks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "task_id", null: false
    t.boolean "liked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_liked_tasks_on_task_id"
    t.index ["user_id", "task_id"], name: "index_liked_tasks_on_user_id_and_task_id", unique: true
    t.index ["user_id"], name: "index_liked_tasks_on_user_id"
  end

  create_table "member_pauses", force: :cascade do |t|
    t.bigint "household_member_id", null: false
    t.bigint "declared_by_id"
    t.date "starts_on", null: false
    t.date "ends_on"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["declared_by_id"], name: "index_member_pauses_on_declared_by_id"
    t.index ["household_member_id", "starts_on"], name: "index_member_pauses_on_household_member_id_and_starts_on"
    t.index ["household_member_id"], name: "index_member_pauses_on_household_member_id"
    t.check_constraint "ends_on IS NULL OR ends_on >= starts_on", name: "member_pauses_dates_ordered"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "event_type", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "event_type"], name: "index_notification_preferences_on_user_id_and_event_type", unique: true
    t.index ["user_id"], name: "index_notification_preferences_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "household_id"
    t.string "kind", null: false
    t.string "event_type", null: false
    t.string "cap_class"
    t.string "dedup_key", null: false
    t.jsonb "facts", default: {}, null: false
    t.string "channel"
    t.string "suppressed_reason"
    t.date "cap_week_start"
    t.datetime "deliver_at", null: false
    t.datetime "dispatched_at"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_notifications_on_household_id"
    t.index ["user_id", "cap_class", "cap_week_start"], name: "index_notifications_weekly_cap", unique: true, where: "((channel IS NOT NULL) AND (cap_class IS NOT NULL))"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "dedup_key"], name: "index_notifications_on_user_id_and_dedup_key", unique: true
    t.index ["user_id"], name: "index_notifications_on_user_id"
    t.check_constraint "channel IS NULL OR suppressed_reason IS NULL", name: "notifications_sent_or_suppressed"
  end

  create_table "recurring_chores", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.bigint "task_id", null: false
    t.bigint "assigned_to_id"
    t.integer "frequency", null: false
    t.integer "time_required"
    t.boolean "mental_load", default: false, null: false
    t.boolean "execution_load", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "active"], name: "index_recurring_chores_on_household_id_and_active"
    t.index ["household_id"], name: "index_recurring_chores_on_household_id"
    t.index ["task_id"], name: "index_recurring_chores_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "name"
    t.integer "time_required"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "recurring", default: false, null: false
    t.string "category", default: "other", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "role", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone", default: "Europe/Paris", null: false
    t.string "first_name", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "week_corrections", force: :cascade do |t|
    t.bigint "household_id", null: false
    t.bigint "household_week_id", null: false
    t.bigint "member_pause_id"
    t.bigint "user_id"
    t.bigint "declared_by_id"
    t.string "first_name", null: false
    t.datetime "declared_at", null: false
    t.datetime "created_at", null: false
    t.index ["declared_by_id"], name: "index_week_corrections_on_declared_by_id"
    t.index ["household_id"], name: "index_week_corrections_on_household_id"
    t.index ["household_week_id", "user_id"], name: "index_week_corrections_on_household_week_id_and_user_id", unique: true
    t.index ["household_week_id"], name: "index_week_corrections_on_household_week_id"
    t.index ["member_pause_id"], name: "index_week_corrections_on_member_pause_id"
    t.index ["user_id"], name: "index_week_corrections_on_user_id"
  end

  add_foreign_key "absence_answers", "absence_inquiries", on_delete: :cascade
  add_foreign_key "absence_answers", "household_members", on_delete: :cascade
  add_foreign_key "absence_answers", "member_pauses", on_delete: :nullify
  add_foreign_key "absence_inquiries", "household_members", on_delete: :cascade
  add_foreign_key "absence_inquiries", "households", on_delete: :cascade
  add_foreign_key "chore_logs", "chores", on_delete: :nullify
  add_foreign_key "chore_logs", "households", on_delete: :nullify
  add_foreign_key "chore_logs", "users"
  add_foreign_key "chores", "households"
  add_foreign_key "chores", "recurring_chores"
  add_foreign_key "chores", "tasks", on_delete: :restrict, validate: false
  add_foreign_key "chores", "users", column: "assigned_to_id"
  add_foreign_key "engine_events", "households", on_delete: :cascade
  add_foreign_key "household_members", "households"
  add_foreign_key "household_members", "users"
  add_foreign_key "household_weeks", "households", on_delete: :cascade
  add_foreign_key "invitations", "households"
  add_foreign_key "invitations", "users", column: "invitee_id", on_delete: :nullify
  add_foreign_key "invitations", "users", column: "inviter_id", on_delete: :nullify
  add_foreign_key "level_changes", "absence_inquiries", on_delete: :nullify
  add_foreign_key "level_changes", "household_weeks", on_delete: :nullify
  add_foreign_key "level_changes", "households", on_delete: :cascade
  add_foreign_key "level_changes", "level_changes", column: "cancelled_level_change_id", on_delete: :nullify
  add_foreign_key "liked_tasks", "tasks"
  add_foreign_key "liked_tasks", "users"
  add_foreign_key "member_pauses", "household_members", on_delete: :cascade
  add_foreign_key "member_pauses", "users", column: "declared_by_id", on_delete: :nullify
  add_foreign_key "notification_preferences", "users", on_delete: :cascade
  add_foreign_key "notifications", "households", on_delete: :cascade
  add_foreign_key "notifications", "users", on_delete: :cascade
  add_foreign_key "recurring_chores", "households"
  add_foreign_key "recurring_chores", "tasks"
  add_foreign_key "recurring_chores", "users", column: "assigned_to_id"
  add_foreign_key "week_corrections", "household_weeks", on_delete: :cascade
  add_foreign_key "week_corrections", "households", on_delete: :cascade
  add_foreign_key "week_corrections", "member_pauses", on_delete: :nullify
  add_foreign_key "week_corrections", "users", column: "declared_by_id", on_delete: :nullify
  add_foreign_key "week_corrections", "users", on_delete: :nullify
end
