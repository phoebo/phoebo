class Task < ActiveRecord::Base
  self.primary_key = :id
  enum state: [ :awaiting, :requesting, :requested, :launched, :running, :finished ]
end
