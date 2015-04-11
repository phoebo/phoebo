class Broker
  class ImmutableTransformation
    def initialize(obj)
      @obj = obj
    end

    # Return diff log and freezes transformation
    def diff
      unless @diff
        @diff = {}
        instance_variables.each do |var|
          next unless var[1] == '_'
          @diff[var[2..-1].to_sym] = instance_variable_get(var)
        end
      end

      @diff
    end

    # Handle reads and writes
    def method_missing(m, *args, &block)
      if @obj.respond_to?(m)
        # Set
        if(m[-1] == '=')
          unless @obj.respond_to?(method = m[0...-1])
            unless @obj.respond_to?(method = "#{m[0...-1]}?")
              super
              return
            end
          end

          if @obj.send(method) != args.first
            instance_variable_set("@_#{m[0...-1]}", args.first)
          elsif instance_variable_defined?(sym = "@_#{m[0...-1]}".to_sym)
            remove_instance_variable(sym)
          end

          @diff = nil

        # Get previously set value
        elsif m[-1] != '?' && instance_variable_defined?(sym = "@_#{m}".to_sym)
          instance_variable_get(sym)

        # Get value on object
        else
          @obj.send(m, *args, &block)
        end
      else
        super
      end
    end
  end
end