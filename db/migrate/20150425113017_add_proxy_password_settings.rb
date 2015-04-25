class AddProxyPasswordSettings < ActiveRecord::Migration
  def change
    add_column :project_settings, :proxy_password, :string
  end
end
