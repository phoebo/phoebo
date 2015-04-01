require 'rails_helper'

RSpec.describe SingularityConnector do
  describe 'request IDs' do
    examples = {
      simple: [ 'phoebo-t123', { task_id: 123 } ],
      full:   [ 'phoebo-p1-b2-t3', { project_id: 1, build_request_id: 2, task_id: 3 } ]
    }

    describe '.request_id' do
      examples.each do |name, example|
        it "builds #{name} request id" do
          expect(described_class.request_id(example.second)).to be == example.first
        end
      end
    end

    describe '.parse_request_id' do
      examples.each do |name, example|
        it "parses #{name} request id" do
          expect(described_class.parse_request_id(example.first)).to be == example.second
        end
      end
    end
  end
end
