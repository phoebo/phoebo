# Model for expressing dynamic set of projects
# Each binding can refer to one or multiple projects
#
# t.integer "kind",  default: 0, null: false
# t.string  "value"
#
class ProjectBinding < ActiveRecord::Base
  has_many :params, class_name: 'ProjectParameter', dependent: :destroy
  accepts_nested_attributes_for :params, reject_if: lambda { |a| a[:name].blank? }, allow_destroy: true

  has_one :settings, class_name: 'ProjectSettings', dependent: :destroy, autosave: true
  accepts_nested_attributes_for :settings

  enum kind: [ :all_projects, :namespace_id, :project_id ]
end
