require 'rails_helper'

RSpec.describe ProjectBinding, type: :model do
  it "has a valid factories" do
    expect(create(:project_binding, :for_project, project_id: 1)).to be_valid
    expect(create(:project_binding, :for_namespace, namespace_id: 1)).to be_valid
    expect(create(:project_binding, :for_all_projects)).to be_valid
  end
end