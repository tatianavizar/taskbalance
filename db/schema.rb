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

ActiveRecord::Schema[8.0].define(version: 2026_06_09_210809) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chore_logs", force: :cascade do |t|
    t.bigint "chore_id", null: false
    t.bigint "household_id", null: false
    t.bigint "user_id", null: false
    t.boolean "mental_load", null: false
    t.boolean "execution_load", null: false
    t.integer "time_spent", null: false
    t.datetime "completed_at", null: false
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

  create_table "household_members", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "household_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_household_members_on_household_id"
    t.index ["user_id"], name: "index_household_members_on_user_id"
  end

  create_table "households", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email", null: false
    t.bigint "household_id", null: false
    t.string "token", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["email", "household_id"], name: "index_invitations_on_email_and_household_id", unique: true
    t.index ["token"], name: "index_invitations_on_token", unique: true
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "chore_logs", "chores"
  add_foreign_key "chore_logs", "users"
  add_foreign_key "chores", "households"
  add_foreign_key "chores", "recurring_chores"
  add_foreign_key "chores", "tasks", on_delete: :restrict, validate: false
  add_foreign_key "chores", "users", column: "assigned_to_id"
  add_foreign_key "household_members", "households"
  add_foreign_key "household_members", "users"
  add_foreign_key "invitations", "households"
  add_foreign_key "liked_tasks", "tasks"
  add_foreign_key "liked_tasks", "users"
  add_foreign_key "recurring_chores", "households"
  add_foreign_key "recurring_chores", "tasks"
  add_foreign_key "recurring_chores", "users", column: "assigned_to_id"
end
