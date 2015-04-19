require 'rails_helper'
require 'support/gitlab.rb'

RSpec.describe ProjectInfo do
  include_context 'gitlab'

  describe '.all collection' do
    # Create user with mocked gitlab
    let(:user) do
      user = build(:user)
      allow(user).to receive(:gitlab).and_return(gitlab)
      user
    end

    it 'returns collection with ProjectInfo' do
      # Enable one project
      enabled_project_id = gitlab.user_projects.values.first[:id]
      project_set = create(:project_set, :for_project, project_id: enabled_project_id)

      projects = described_class.all(for_user: user)

      expect(projects.size).to be == gitlab.user_projects.length
      expect(projects.select { |p| p.id == enabled_project_id }.first.enabled?).to be true
    end
  end

end
