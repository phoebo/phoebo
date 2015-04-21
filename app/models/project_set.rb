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

      init_helper(args, options)
    end

    def for_namespace(namespace_id, options = {})
      args = {
        kind: self.kinds[:with_namespace_id],
        filter_pattern: namespace_id
      }

      init_helper(args, options)
    end

    def for_all_projects(options = {})
      args = {
        kind: self.kinds[:all_projects]
      }

      init_helper(args, options)
    end

    private

    def init_helper(args, options = {})
      if options[:init]
        self.find_or_initialize_by(args)
      else
        self.find_by(args)
      end
    end
  end

  # TODO: implement method for getting super sets
end
