require 'rails_helper'

RSpec.describe ProjectSet, type: :model do
  it "has a valid factory" do
    expect(create(:project_set, :for_project, project_id: 1)).to be_valid
  end
end