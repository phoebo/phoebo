require 'rails_helper'
require File.expand_path('../../../lib/nested.rb', __FILE__)

RSpec.describe Nested do
  subject {
    nested {
      property :foo, :required
      property :bar, :required
      property :a, default: 1
      property :b, :my_trait

      nested(:info) {
        property :a, :required
        property :b, default: 33
        property :c, :my_trait
      }

      nested(:x, :required) {
        nested(:y, :required) {
          property :z, :required
        }
      }

      trait(:my_trait) { |obj, k|
        raise ArgumentError.new("My trait error") if obj.send(k) == 1
      }
    }
  }

  let(:data) {{
    foo: 'foo',
    b: 1,
    bad_key: 11,
    info: {
      b: 'b',
      bad: 'bad'
    }
  }}

  it 'loads data and returns errors' do
    errors = subject.load!(data)

    expect(subject.foo).to be == 'foo'
    expect(subject.a).to be == 1
    expect(subject.info.b).to be == 'b'
    expect(subject.info.c).to be == nil

    expect(errors).to include([subject, :bad_key, 'Invalid key'])
    expect(errors).to include([subject, :b, 'My trait error'])
    expect(errors).to include([subject.info, :a, 'Missing value'])
    expect(errors).to include([subject.info, :bad, 'Invalid key'])
    expect(errors).to include([subject, :bar, 'Missing value'])
    expect(errors).to include([subject, :x, 'Missing value'])
  end
end