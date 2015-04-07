require 'rails_helper'
require File.expand_path('../../../../lib/broker.rb', __FILE__)

RSpec.describe Broker::Task do
  it "has a valid factory" do
    expect(build(:broker_task)).to be_a(Broker::Task)
    expect(build(:broker_task, :running).run_id).not_to be_nil
  end

  # it do
  #   task = described_class.new
  #   puts task.valid_next_state?(task.class::STATE_FRESH).inspect
  #   puts task.state
  # end
end