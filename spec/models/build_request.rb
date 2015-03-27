require 'rails_helper'

RSpec.describe BuildRequest, type: :model do
  it "has a valid factory" do
    expect(create(:build_request)).to be_valid
  end
end
