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

ActiveRecord::Schema.define(version: 20150402140615) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "build_requests", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string  "secret",     null: false
    t.string  "ref",        null: false
  end

  create_table "projects", force: :cascade do |t|
    t.string "name",           null: false
    t.string "path",           null: false
    t.string "namespace_name", null: false
    t.string "namespace_path", null: false
    t.string "url",            null: false
    t.string "repo_url",       null: false
    t.text   "public_key",     null: false
    t.text   "private_key",    null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "build_request_id",               null: false
    t.string  "mesos_id",         default: "",  null: false
    t.integer "kind",             default: 0,   null: false
    t.json    "deploy_template",                null: false
    t.integer "state",            default: 100, null: false
    t.string  "state_message",    default: "",  null: false
    t.string  "name",             default: "",  null: false
  end

  add_index "tasks", ["build_request_id"], name: "index_tasks_on_build_request_id", using: :btree

end
