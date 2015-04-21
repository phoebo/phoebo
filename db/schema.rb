# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150421083141) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "project_bindings", force: :cascade do |t|
    t.integer "kind",  default: 0, null: false
    t.integer "value"
  end

  create_table "project_parameters", force: :cascade do |t|
    t.integer "project_binding_id"
    t.text    "name",                           null: false
    t.text    "value"
    t.integer "flag",               default: 0, null: false
  end

  add_index "project_parameters", ["project_binding_id"], name: "index_project_parameters_on_project_binding_id", using: :btree

  create_table "project_settings", force: :cascade do |t|
    t.integer "project_binding_id"
    t.integer "memory"
    t.float   "cpu"
    t.text    "public_key"
    t.text    "private_key"
  end

  add_index "project_settings", ["project_binding_id"], name: "index_project_settings_on_project_binding_id", using: :btree

end
