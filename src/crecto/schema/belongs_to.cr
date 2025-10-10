module Crecto
  module Schema
    module BelongsTo
      # :nodoc:
      CRECTO_VALID_BELONGS_TO_OPTIONS = [:foreign_key]

      macro belongs_to(association_name, klass, **opts)
        {% unless @type.has_constant? "CRECTO_ASSOCIATIONS" %}
          Crecto::Schema::Associations.setup_associations
        {% end %}

        @{{association_name.id}} : {{klass}}?

        def {{association_name.id}}? : {{klass}}?
          @{{association_name.id}}
        end

        def {{association_name.id}} : {{klass}}
          {{association_name.id}}? || raise Crecto::AssociationNotLoaded.new("Association `{{association_name.id}}' is not loaded or is nil. Use `{{association_name.id}}?' if the association is nilable.")
        end


        {%
          foreign_key = klass.id.stringify.split(":")[-1].id.stringify.underscore.downcase + "_id"
          foreign_key = opts[:foreign_key] if opts[:foreign_key]
        %}

        {% unless CRECTO_FIELDS.select { |f| f[:name] == foreign_key.id.symbolize }.size > 0 %}
          field {{foreign_key.id.symbolize}}, PkeyValue
        {% end %}

        def {{association_name.id}}=(val : {{klass}}?)
          @{{association_name.id}} = val
          return if val.nil?
          @{{foreign_key.id}} = val.pkey_value.as(PkeyValue)
        end

        CRECTO_ASSOCIATIONS.push({
          association_type: :belongs_to,
          key: {{association_name}},
          this_klass: {{@type}},
          klass: {{klass}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model){
            item.as({{@type}}).{{foreign_key.id}}.as(PkeyValue)
          },
          set_association: ->(self_item : Crecto::Model, items : Array(Crecto::Model) | Crecto::Model){
            if items.is_a?(Array)
              array_items = items.as(Array)
              if array_items.size > 0
                self_item.as({{@type}}).{{association_name.id}} = array_items[0].as({{klass}})
              else
                self_item.as({{@type}}).{{association_name.id}} = nil
              end
            else
              self_item.as({{@type}}).{{association_name.id}} = items.as({{klass}})
            end
            nil
          },
          through: nil
        })
      end
    end
  end
end
