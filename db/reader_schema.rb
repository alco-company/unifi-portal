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

ActiveRecord::Schema[8.1].define(version: 2025_06_27_130646) do
  create_table "admin_tenants", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "guest_max"
    t.string "guest_rx"
    t.string "guest_tx"
    t.string "login"
    t.string "name"
    t.string "password"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "sites", force: :cascade do |t|
    t.string "api_key"
    t.string "controller_id"
    t.string "controller_url"
    t.datetime "created_at", null: false
    t.string "ssid"
    t.datetime "updated_at", null: false
    t.string "url"
  end
end
