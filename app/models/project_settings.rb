# Project settings
#
# t.integer :memory
# t.float :cpu
# t.text :public_key
# t.text :private_key
# t.string :proxy_password
#
class ProjectSettings < ActiveRecord::Base
  DEFAULTS = {
    cpu: 0.1,
    memory: 128
  }

  belongs_to :project_binding
  validates :cpu, numericality: { greater_than: 0 }, allow_nil: true
  validates :memory, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
