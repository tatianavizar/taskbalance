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

ActiveRecord::Schema[8.0].define(version: 2025_01_16_122559) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chores", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "household_id", null: false
    t.bigint "user_id"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_chores_on_household_id"
    t.index ["task_id"], name: "index_chores_on_task_id"
    t.index ["user_id"], name: "index_chores_on_user_id"
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

  create_table "liked_tasks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "task_id", null: false
    t.boolean "liked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_liked_tasks_on_task_id"
    t.index ["user_id"], name: "index_liked_tasks_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "name"
    t.integer "time_required"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  add_foreign_key "chores", "households"
  add_foreign_key "chores", "tasks"
  add_foreign_key "chores", "users"
  add_foreign_key "household_members", "households"
  add_foreign_key "household_members", "users"
  add_foreign_key "liked_tasks", "tasks"
  add_foreign_key "liked_tasks", "users"
end
