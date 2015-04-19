# Model for expressing dynamic set of projects
class ProjectSet < ActiveRecord::Base
  has_many :params, foreign_key: 'project_set_id', class_name: 'ProjectParameter', dependent: :destroy
  accepts_nested_attributes_for :params, reject_if: lambda { |a| a[:name].blank? }, allow_destroy: true

  has_one :settings, class_name: 'ProjectSettings', dependent: :destroy, autosave: true
  accepts_nested_attributes_for :settings

  enum kind: [ :all_projects, :with_namespace_id, :with_project_id ]

  class << self
    def for_project(project_id, options = {})
      args = {
        kind: self.kinds[:with_project_id],
        filter_pattern: project_id
      }

      if options[:init]
        self.find_or_initialize_by(args)
      else
        self.find_by(args)
      end
    end
  end

  # TODO: implement method for getting super sets
end
