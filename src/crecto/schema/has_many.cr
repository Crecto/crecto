module Crecto
  module Schema
    module HasMany
      VALID_HAS_MANY_OPTIONS = [:foreign_key]

      macro has_many(association_name, klass, **opts)        
        property {{association_name.id}} : Array({{klass}})?

        def class_for_association_{{association_name.id}}
          {{klass}}
        end

        def foreign_key_for_association_{{association_name.id}}
          foreign_key = {{@type.id.symbolize.downcase}}_id

          {% if opts[:foreign_key] %}
            foreign_key = {{opts[:foreign_key]}}
          {% end %}

          foreign_key
        end

        def value_for_association_{{association_name.id}}
          pkey_value
        end
      end
    end
  end
end