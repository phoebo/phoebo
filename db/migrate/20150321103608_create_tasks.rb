class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks, id: false do |t|
      t.string :id, primary: true
      t.string :mesos_id, null: false, default: ''
      t.integer :state, null: false, default: 0
    end

    execute %Q{ ALTER TABLE tasks ADD PRIMARY KEY (id); }
  end
end
