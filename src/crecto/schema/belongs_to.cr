module Crecto
  module Schema
    module BelongsTo
      VALID_BELONGS_TO_OPTIONS = [:foreign_key]

      macro belongs_to(association_name, klass, **opts)
        property {{association_name.id}} : Array({{klass}})?

        def class_for_association_{{association_name.id}}
          {{klass}}
        end

        def foreign_key_for_association_{{association_name.id}}
          :id
        end

        def value_for_association_{{association_name.id}}
          val = {{klass.id.symbolize.downcase.id}}_id.as(Int32 | Int64)

          {% if opts[:foreign_key] %}
            val = {{opts[:foreign_key].id}}.as(Int32 | Int64)
          {% end %}

          val
        end
      end
    end
  end
end