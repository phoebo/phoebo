require 'rails_helper'

RSpec.describe ProjectAccessor do
  let(:project_id) { 1 }
  let(:namespace_id) { 1 }
  subject(:accessor) { described_class.new(namespace_id, project_id) }

  context 'all sets' do
    let(:bindings) {{
      project:   create(:project_binding, :for_project,   project_id: project_id,
        settings: build(:project_settings, cpu: 0.5)),

      namespace: create(:project_binding, :for_namespace, namespace_id: namespace_id),

      default:   create(:project_binding, :for_all_projects,
        settings: build(:project_settings, cpu: 0.2, memory: 128))
    }}

    before { bindings }

    it '.each' do
      expect { |b| accessor.each(&b) }.to yield_successive_args(*bindings.values)
    end

    it 'provides named [key] acccess' do
      bindings.each do |key, project_binding|
        expect(accessor[key]).to be == project_binding
      end
    end

    it '.settings' do
      expect(accessor.settings(:cpu)).to be == 0.5
      expect(accessor.settings(:memory)).to be == 128
    end

    it '.effective_settings' do
      create(:project_parameter, project_binding: bindings[:project], name: 'foo', value: 'bar2')
      create(:project_parameter, project_binding: bindings[:default], name: 'foo', value: 'bar')
      create(:project_parameter, project_binding: bindings[:default], name: 'baboon', value: 'BABOON!')

      expect(accessor.effective_params).to be == {
        foo: 'bar2',
        baboon: 'BABOON!'
      }
    end
  end

  context 'only project settings' do
    let(:bindings) {{
      project:   create(:project_binding, :for_project, project_id: project_id),
    }}

    it '.each' do
      expect { |b| accessor.each(&b) }.to yield_successive_args(*bindings.values)
    end

    it 'provides named [key] acccess' do
      bindings.each do |key, project_binding|
        expect(accessor[key]).to be == project_binding
      end
    end

    it 'initializes new namespace set' do
      expect(accessor[:namespace]).not_to be_persisted
    end

    it 'initializes new default set' do
      expect(accessor[:default]).not_to be_persisted
    end
  end
end