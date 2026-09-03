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

ActiveRecord::Schema[8.1].define(version: 2026_09_03_000001) do
  create_table "answers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "interaction_id", null: false
    t.integer "question_id"
    t.string "question_text"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["interaction_id"], name: "index_answers_on_interaction_id"
    t.index ["question_id"], name: "index_answers_on_question_id"
  end

  create_table "interactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "queue_id", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["queue_id", "position"], name: "index_interactions_on_queue_id_and_position"
    t.index ["queue_id"], name: "index_interactions_on_queue_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "questions", force: :cascade do |t|
    t.json "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.integer "profile_id", null: false
    t.string "question_type", default: "text", null: false
    t.string "text", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_questions_on_profile_id"
  end

  create_table "queues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "current", default: false, null: false
    t.date "date"
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_queues_on_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "answers", "interactions"
  add_foreign_key "answers", "questions"
  add_foreign_key "interactions", "queues"
  add_foreign_key "profiles", "users"
  add_foreign_key "questions", "profiles"
  add_foreign_key "queues", "profiles"
end
