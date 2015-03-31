require 'rails_helper'

RSpec.describe User do
  it 'has a factories' do
    build(:user)
    build(:admin_user)
    build(:basic_user)
  end

  it 'constructs with attributes' do
    user = described_class.new({ id: val = 123 })
    expect(user.attributes[:id]).to be val
  end

  it 'assigns attribute' do
    subject.id = val = 123
    expect(subject.attributes[:id]).to be val
  end

  it 'reads attribute' do
    user = described_class.new({ id: val = 123 })
    expect(user.id).to be val
  end

  it 'raises error on invalid attribute' do
    expect { subject.foobar }.to raise_error(NoMethodError)
    expect { subject.foobar = 123 }.to raise_error(NoMethodError)
  end
end
