class Project < ActiveRecord::Base
  class << self
    def find_owned_by(user)
      self.where(id: user.gitlab.cached_user_projects.keys)
    end
  end
end
