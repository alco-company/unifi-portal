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

ActiveRecord::Schema[8.1].define(version: 2025_07_02_113002) do
  create_table "clients", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "guest_max", default: 0
    t.integer "guest_rx", default: 0
    t.integer "guest_tx", default: 0
    t.string "name"
    t.text "note"
    t.string "phone"
    t.integer "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_clients_on_tenant_id"
  end

  create_table "devices", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "authentication_expire_at"
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.integer "guest_max", default: 0
    t.integer "guest_rx", default: 0
    t.integer "guest_tx", default: 0
    t.string "last_ap"
    t.datetime "last_authenticated_at"
    t.string "last_otp"
    t.string "mac_address"
    t.integer "site_id"
    t.string "unifi_id"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_devices_on_client_id"
    t.index ["site_id"], name: "index_devices_on_site_id"
  end

  create_table "sites", force: :cascade do |t|
    t.boolean "active", default: true
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
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.integer "guest_max", default: 0
    t.integer "guest_rx", default: 0
    t.integer "guest_tx", default: 0
    t.string "name"
    t.text "note"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.string "phone"
    t.boolean "superuser"
    t.integer "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
  end

  add_foreign_key "clients", "tenants"
  add_foreign_key "devices", "clients"
  add_foreign_key "devices", "sites"
  add_foreign_key "sites", "tenants"
  add_foreign_key "users", "tenants"
end
