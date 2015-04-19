require 'rails_helper'
require File.expand_path('../../../../lib/broker.rb', __FILE__)

RSpec.describe Broker::ImmutableTransformation do
	let(:task) { build(:broker_task) }
	subject(:transformation) { described_class.new(task) }

	it 'creates diff' do
		transformation.has_output = true
		expect(transformation.diff).to be == { has_output: true }
	end
end