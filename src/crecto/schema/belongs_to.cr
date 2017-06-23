module Crecto
  module Schema
    module BelongsTo
      # :nodoc:
      VALID_BELONGS_TO_OPTIONS = [:foreign_key]

      macro belongs_to(association_name, klass, **opts)
        @{{association_name.id}} : {{klass}}?

        def {{association_name.id}}? : {{klass}}?
          @{{association_name.id}}
        end

        def {{association_name.id}} : {{klass}}
          {{association_name.id}}? || raise Crecto::AssociationNotLoaded.new("Association `{{association_name.id}}' is not loaded or is nil. Use `{{association_name.id}}?' if the association is nilable.")
        end


        {%
          foreign_key = klass.id.stringify.underscore.downcase + "_id"
          foreign_key = opts[:foreign_key] if opts[:foreign_key]
        %}

        {% unless FIELDS.select { |f| f[:name] == foreign_key.id.symbolize }.size > 0 %}
          field {{foreign_key.id.symbolize}}, PkeyValue
        {% end %}

        def {{association_name.id}}=(val : {{klass}}?)
          @{{association_name.id}} = val
          return if val.nil?
          @{{foreign_key.id}} = val.pkey_value.as(PkeyValue)
        end

        ASSOCIATIONS.push({
          association_type: :belongs_to,
          key: {{association_name}},
          this_klass: {{@type}},
          klass: {{klass}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model){
            item.as({{@type}}).{{foreign_key.id}}.as(PkeyValue)
          },
          set_association: ->(self_item : Crecto::Model, items : Array(Crecto::Model) | Crecto::Model){
            self_item.as({{@type}}).{{association_name.id}} = items.as(Array(Crecto::Model))[0].as({{klass}});nil
          },
          through: nil
        })
      end
    end
  end
end
