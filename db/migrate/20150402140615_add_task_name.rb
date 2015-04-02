class AddTaskName < ActiveRecord::Migration
  def change
    add_column :tasks, :name, :string, null: false, default: '', first: true
  end
end
