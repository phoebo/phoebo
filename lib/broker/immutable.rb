class Broker
  module Immutable
    # Redefine dup method while maintaining the original private
    alias_method :__immutable_dup__, :dup
    private :__immutable_dup__

    def dup
      self
    end

    def clone
      self
    end

    # We count generations
    def generation
      @generation || 0
    end

    # Transformation helper
    def transform(&block)
      obj = self
      transformation = ImmutableTransformation.new(self).tap(&block)

      # Add apply method which creates changed immutable object duplicate
      transformation.define_singleton_method(:apply) do
        if diff.empty?
          obj
        else
          # We might be transforming fresh, unfrozen, object
          obj2 = obj.frozen? ? obj.send(:__immutable_dup__) : obj

          # Apply all the transformations
          diff.each do |key, value|
            obj2.send("#{key}=", value)
          end

          # Increment generation number
          obj2.instance_variable_set(:@generation, obj.generation + 1)
          obj2.freeze
        end
      end

      transformation
    end
  end
end