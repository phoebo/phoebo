class InitialSchema < ActiveRecord::Migration
  def change
    create_table :project_bindings do |t|
      t.integer :kind, null: false, default: 0
      t.integer :value
    end

    create_table :project_settings do |t|
      t.belongs_to :project_binding, index: true

      t.integer :memory
      t.float :cpu
      t.text :public_key
      t.text :private_key
    end

    create_table :project_parameters do |t|
      t.belongs_to :project_binding, index: true

      t.text :name, null: false
      t.text :value
      t.integer :flag, null: false, default: 0
    end
  end
end
