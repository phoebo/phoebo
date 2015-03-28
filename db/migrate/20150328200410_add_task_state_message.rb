class AddTaskStateMessage < ActiveRecord::Migration
  def change
    add_column :tasks, :state_message, :string, null: false, default: ''
  end
end
