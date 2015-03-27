require 'active_record/connection_adapters/postgresql_adapter'

# Patched JSON deserialization to use symbols instead of strings
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Json
          def type_cast_from_database(value)
            if value.is_a?(::String)
              JSON.parse(value, symbolize_names: true)
            else
              super
            end
          end
        end
      end
    end
  end
end