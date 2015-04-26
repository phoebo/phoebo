module Nested
  module Traits
    module ClassMethods
      # Return all defined traits
      def traits
        @traits ||= {}
      end

      # Define trait
      def trait(id, &block)
        raise ArgumentError.new("Invalid trait ID, expected Symbol.") unless id.is_a? Symbol
        raise ArgumentError.new("Expected block for trait definition") unless block_given?

        traits[id] = block
      end
    end

    extend ClassMethods

    trait(:required) { |obj, key|
      val = obj.send(key)

      if val.is_a?(Nested)
        raise ArgumentError.new("Missing value") if val.empty?
      else
        raise ArgumentError.new("Missing value") if val.nil?
      end
    }

    trait(:default) { |obj, key, default_value|
      obj.send("#{key}=", default_value) if obj.send(key).nil?
    }
  end

  module ClassMethods
    attr_reader :key, :parent

    # Defined properties
    def properties
      @properties ||= {}
    end

    # Define scalar property
    def property(*args)
      id, traits = parse_property_args(args)
      raise ArgumentError.new("Unexpected block for property") if block_given?

      properties[id] = [ :property ] + traits
      attr_accessor id
    end

    # Define nested property
    def nested(*args, &block)
      id, traits = parse_property_args(args)
      raise ArgumentError.new("Expected block for nested property") unless block_given?

      properties[id] = [ :nested ] + traits

      # Define getter
      var_sym = "@#{id}".to_sym
      c = Nested.class_factory(self, id, &block)

      define_method id do
        unless instance_variable_defined?(var_sym)
          instance_variable_set(var_sym, c.new)
        end

        instance_variable_get(var_sym)
      end
    end

    # Key lookup
    def absolute_key(id = nil)
      key = [ ]
      key << id unless id.nil?
      key << @key unless @key.nil?

      c = @parent

      while c
        key << c.key unless c.key.nil?
        c = c.parent
      end

      key.reverse
    end

    private

    def parse_property_args(args)
      raise ArgumentError.new("Missing property ID.") unless args.length > 0
      raise ArgumentError.new("Invalid property ID, expected Symbol.") unless args.first.is_a? Symbol

      # ID
      id = args.shift

      # Return
      [ id, args ]
    end
  end

  # Returns TRUE if any of the properties is set
  def empty?
    self.class.properties.each do |key, prop|
      if prop.first == :nested
        return false unless send(key).empty?
      else
        return false unless send(key).nil?
      end
    end

    return true
  end

  # Iteration
  def each(&block)
    self.class.properties.collect { |key, _| [ key, send(key) ] } .to_h.each(&block)
  end

  # Serialize for inspection
  def inspect
    str = "#<Nested:#{object_id}"

    self.class.properties.each.with_index do |pair, index|
      k, _ = pair
      str += "," unless index == 0
      str += " #{k.inspect}=>#{send(k).inspect}"
    end

    str + ">"
  end

  # Load data from hash and return array of errors
  def load!(data, options = {})
    errors = []
    properties = self.class.properties

    # Load data
    data.each do |k, v|
      k = k.to_sym if options[:symbolize_keys]

      error_msg = catch(:error) do
        if properties.include?(k)
          if v.respond_to? :each
            if properties[k].first == :nested
              errors += send(k).load!(v, options)
            else
              throw(:error, "Expected scalar")
            end
          else
            if properties[k].first == :property
              send("#{k}=", v)
            else
              throw(:error, "Expected nested structure")
            end
          end
        else
          throw(:error, "Invalid key")
        end

        throw(:error, nil)
      end

      if error_msg
        errors << [ self, k, error_msg ]
      end
    end

    # Apply traits for each property
    properties.each do |k, prop|
      prop.shift
      prop.each do |trait|
        # Prepare arguments
        if trait.is_a? Hash
          id = trait.keys.first
          args = [ trait[id] ]
        else
          id   = trait
          args = []
        end

        # Lookup trait
        trait_proc = catch(:trait) do
          throw(:trait, Traits.traits[id]) if Traits.traits[id]

          c = self.class
          while c
            throw(:trait, c.traits[id]) if c.traits[id]
            c = c.parent
          end

          raise "Undefined trait #{id.inspect}"
        end

        # Call trait
        begin
          trait_proc.call(self, k, *args)
        rescue ArgumentError => e
          errors << [ self, k, e.message ]
        end
      end
    end

    # Define serialization for error Array
    errors.define_singleton_method :to_s do
       collect { |item| "#{item[0].class.absolute_key(item[1]).join('.')}: #{item[2]}" } .join(', ')
    end

    errors
  end

  # Auto-extend on include
  def self.included(base)
    base.extend(ClassMethods)
    base.extend(Traits::ClassMethods)
  end

  # Create anonymous nested class using given block
  def self.class_factory(parent = nil, key = nil, &block)

    c = Class.new
    c.include(Nested)

    c.instance_variable_set(:@parent, parent)
    c.instance_variable_set(:@key, key)

    c.instance_eval(&block)

    c
  end
end

# Create nested class instance
def nested(&block)
  raise ArgumentError.new("Expected block for nested property") unless block_given?

  c = Nested.class_factory(&block)
  c.new
end