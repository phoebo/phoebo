class AddTaskMesosInfo < ActiveRecord::Migration
  def change
    add_column :tasks, :mesos_info, :json, null: false, default: '{}', after: :mesos_id
  end
end
