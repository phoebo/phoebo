# Project settings
class ProjectSettings < ActiveRecord::Base
  belongs_to :project_set
  validates :cpu, numericality: { greater_than: 0 }, allow_nil: true
  validates :memory, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
