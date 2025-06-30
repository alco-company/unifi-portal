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

ActiveRecord::Schema[8.1].define(version: 2025_06_30_121914) do
  create_table "clients", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "guest_max"
    t.integer "guest_rx"
    t.integer "guest_tx"
    t.string "name"
    t.string "phone"
    t.integer "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_clients_on_tenant_id"
  end

  create_table "sites", force: :cascade do |t|
    t.boolean "active"
    t.string "api_key"
    t.string "controller_url"
    t.datetime "created_at", null: false
    t.integer "guest_max", default: 0, null: false
    t.integer "guest_rx", default: 0, null: false
    t.integer "guest_tx", default: 0, null: false
    t.string "name"
    t.string "ssid"
    t.integer "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["tenant_id"], name: "index_sites_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "login"
    t.string "name"
    t.string "password"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "clients", "tenants"
  add_foreign_key "sites", "tenants"
end
