class BuildRequest < ActiveRecord::Base
	belongs_to :project
	after_initialize :initialize_secret

	private

	def initialize_secret
		self.secret ||= SecureRandom.hex
	end
end
