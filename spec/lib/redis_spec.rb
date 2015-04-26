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
end