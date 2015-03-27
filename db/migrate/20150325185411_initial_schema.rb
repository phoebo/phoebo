class InitialSchema < ActiveRecord::Migration
  def change

    create_table :projects do |t|
      t.string :name, null: false
      t.string :path, null: false
      t.string :namespace_name, null: false
      t.string :namespace_path, null: false
      t.string :url, null: false
      t.string :repo_url, null: false
      t.text :public_key, null: false
      t.text :private_key, null: false
    end

    create_table :build_requests do |t|
      t.integer :project_id, null: false
      t.string :secret, null: false
      t.string :ref, null: false
    end

    create_table :tasks do |t|
      t.integer :build_request_id, null: false
      t.string :mesos_id, null: false, default: ''
      t.integer :kind, null: false, default: Task.kinds[:oneoff]
      t.json :deploy_template, null: false
      t.integer :state, null: false, default: Task.states[:fresh]
    end

    add_index :tasks, :build_request_id, using: :btree
  end
end
