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

ActiveRecord::Schema[8.1].define(version: 2026_05_27_202720) do
  create_table "blocks", force: :cascade do |t|
    t.boolean "auto", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.string "external_id"
    t.text "note", default: "", null: false
    t.string "quadrant", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "external_id"], name: "index_blocks_on_user_id_and_external_id", unique: true
    t.index ["user_id", "starts_at"], name: "index_blocks_on_user_id_and_starts_at"
    t.index ["user_id"], name: "index_blocks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "api_token", null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "blocks", "users"
end
