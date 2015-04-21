# Accessor for project data bound by multiple project bindings
# This model is used for traversing through the binding fallback.
class ProjectAccessor

  # Constructor
  def initialize(namespace_id = nil, project_id = nil)
    @attributes = {}
    @attributes[:project]   = { kind: 'project_id',   value: project_id }   if project_id
    @attributes[:namespace] = { kind: 'namespace_id', value: namespace_id } if namespace_id
    @attributes[:default]   = { kind: 'all_projects' }
  end

  # Parent accessor
  def parent

    # Skip first
    if !@attributes.empty?
      new_attrs = @attributes.dup
      new_attrs.delete(@attributes.keys.first)
    else
      new_attrs = {}
    end

    # TODO: use already loaded bindings to avoid multiple queries

    p = self.class.new
    p.instance_variable_set(:@attributes, new_attrs)
    p
  end

  # Array access
  def [](key)
    # Convert key if necessary
    if @attributes.include?(key)
      bindings.each do |binding|
        catch(:finder) do
          # Check for match
          @attributes[key].each do |attr_key, attr_value|
            throw(:finder) unless binding.send(attr_key) == attr_value
          end

          # We have a match
          return binding
        end
      end

      # Initialize if we don't have it yet
      # Note: do we need to add to add it to @bindings?
      return ProjectBinding.new(@attributes[key])
    end

    # Basic indexing
    bindings[key]
  end

  # Enumaration
  def each(&block)
    bindings.each(&block)
  end

  # Settings accessor
  def settings(key)
    bindings.each do |binding|
      unless (binding.settings && val = binding.settings.send(key)).nil?
        return val
      end
    end

    ProjectSettings::DEFAULTS.include?(key) ? ProjectSettings::DEFAULTS[key] : nil
  end

  # Returns effective params as a Hash
  def effective_params
    params = { }
    bindings.each do |project_set|
      project_set.params.each do |param|
        unless params.include?(sym = param.name.to_sym)
          params[sym] = param.value
        end
      end
    end

    params
  end

  private

  # Data loader
  def bindings
    unless @bindings
      if @attributes.empty?
        @bindings = []
      else
        # Prepare query attributes from @attributes
        args = [ '' ]
        @attributes.each.with_index do |pair, index|
          _, set_attr = pair
          args[0] += ' OR ' unless index == 0

          args[0] += '(' unless set_attr.length == 1

          set_attr.each.with_index do |pair, index|
            key, value = pair
            args[0] += ' AND ' unless index == 0
            args[0] += "%s = ?" % ActiveRecord::Base.connection.quote_column_name(key)
            args << (key == :kind ? ProjectBinding.kinds[value] : value)
          end

          args[0] += ')' unless set_attr.length == 1
        end

        # Create empty @bindings array using @attributes as keys
        @bindings = @attributes.keys.collect { |k| [k, nil] }.to_h

        # Fill in existing project sets
        @bindings = ProjectBinding.includes(:settings).where(*args).order(kind: :desc).to_a
      end
    end

    @bindings
  end
end