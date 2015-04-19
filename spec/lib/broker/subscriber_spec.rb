require 'rails_helper'
require File.expand_path('../../../../lib/broker.rb', __FILE__)

RSpec.describe Broker::Subscriber do
  let(:task) { build(:broker_task) }
  let(:task_log) { Hamster.list("Some outputted data") }
  let(:tasks) { Hamster.hash({ task.id => task }) }

  let(:broker) do
    broker = instance_double(Broker)
    allow(broker).to receive(:tasks).and_return(tasks)
    allow(broker).to receive(:task_log).with(task.id).and_return(task_log)
    broker
  end

  subject(:subscriber) { described_class.new(broker) }

  context ':task_update' do
    it 'calls handlers' do
      handler_args = nil
      subscriber.handle(:task_update) { |*args| handler_args = args }

      subscriber.subscribe_for(:task_update, id: task.id)

      # Initial state
      expect(handler_args).to be == [ task, nil, nil ]
      handler_args = nil

      # Send change
      subscriber.process(:task_update, task, task, [])

      # New data
      expect(handler_args).to be == [ task, task, [] ]
    end
  end

  context ':task_output' do
    it 'calls handlers' do
      handler_args = nil
      subscriber.handle(:task_output) { |*args| handler_args = args }

      subscriber.subscribe_for(:task_output, id: task.id)

      # Initial state
      expect(handler_args[0]).to be == task
      expect(handler_args[1]).to be_a(Enumerator)
      handler_args = nil

      subscriber.process(:task_output, task, 'Some other data')

      # New data
      expect(handler_args).to be == [ task, 'Some other data' ]
    end

    it 'subscribe / unsubscribe' do
      subscriber.handle(:task_output) { |*args| nil }

      f1 = subscriber.subscribe_for(:task_output, id: task.id)
      expect(f1).to be == Hamster::hash(id: Hamster::vector(task.id))

      f2 = subscriber.unsubscribe_from(:task_output, id: task.id)
      expect(f2).to be_nil
    end
  end
end