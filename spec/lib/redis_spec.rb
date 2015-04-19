require 'rails_helper'
require File.expand_path('../../../lib/core_ext/redis.rb', __FILE__)

RSpec.describe Redis do
  describe '.composite_key' do
    it 'builds string' do
      expect(described_class.composite_key('a', 'b', 'c')).to be == 'a/b/c'
    end

    it 'escapes delimiter' do
      expect(described_class.composite_key('a', 'b/c', 'd')).to be == 'a/b\/c/d'
    end
  end

  describe '.key_for_task_updates' do
    it 'builds key for project tasks' do
      expect(described_class.key_for_task_updates(project_id: 1, build_request_id: 2, task_id: 3))
        .to be == 'project/1/build_request/2/task/3/updates'
    end

    it 'builds key for non-project tasks' do
      expect(described_class.key_for_task_updates(task_id: 123))
        .to be == 'project/-/build_request/-/task/123/updates'
    end
  end

  describe '.parse_key_for_task_updates' do
    it 'parses key for project tasks' do
      expect(described_class.parse_key_for_task_updates('project/1/build_request/2/task/3/updates'))
        .to be == { project_id: 1, build_request_id: 2, task_id: 3 }
    end

    it 'parses key for non-project tasks' do
      expect(described_class.parse_key_for_task_updates('project/-/build_request/-/task/123/updates'))
        .to be == { task_id: 123 }
    end
  end


  describe '.key_for_mesos_log_updates' do
    it 'builds key' do
      expect(described_class.key_for_mesos_log_updates('phoebo-p1-b1-t5-2-1427645113738-1-mesos.local-DEFAULT'))
        .to be == 'mesos_task/phoebo-p1-b1-t5-2-1427645113738-1-mesos.local-DEFAULT/log_updates'
    end
  end

  describe '.parse_key_for_mesos_log_updates' do
    it 'parses key' do
      expect(described_class.parse_key_for_mesos_log_updates('mesos_task/phoebo-p1-b1-t5-2-1427645113738-1-mesos.local-DEFAULT/log_updates'))
        .to be == 'phoebo-p1-b1-t5-2-1427645113738-1-mesos.local-DEFAULT'
    end
  end

end