require 'rails_helper'
require File.expand_path('../../../lib/broker.rb', __FILE__)
require "hamster"

RSpec.describe Broker do
  let(:fresh_task) { build(:broker_task) }
  let(:running_task) { build(:broker_task, :running) }

  subject(:broker) do
    described_class.new([ fresh_task, running_task ])
  end

  describe '.update_task' do
    it 'updates the task' do
      broker.update_task(1) do |task|
        task.name = 'Foo'
      end

      expect(broker.task(1).name).to be == 'Foo'
    end
  end

  describe '.log_task_output' do
    it 'broadcast the update' do
      broker.log_task_output(running_task.run_id, 'Some outputed data')
    end
  end

  it 'broadcasts to all subscribers' do
    allow(Broker::Subscriber).to receive(:new) { instance_double(Broker::Subscriber) }

    s1 = broker.new_subscriber
    s2 = broker.new_subscriber
    args = [ :task_update, nil, nil, nil ]

    expect(s1).to receive(:process).with(*args)
    expect(s2).to receive(:process).with(*args)

    broker.send(:broadcast, *args)
  end
end