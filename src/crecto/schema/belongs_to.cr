module Crecto
  module Schema
    module BelongsTo
      # :nodoc:
      CRECTO_VALID_BELONGS_TO_OPTIONS = [:foreign_key]

      macro belongs_to(association, **opts)
        #
        # BELONGS TO: {{ @type.id }}
        #
        {% unless @type.has_constant? "CRECTO_ASSOCIATIONS" %}
          Crecto::Schema::Associations.setup_associations
        {% end %}

        {%
          field_name = association.var
          field_type = association.type
          fkey_type = opts[:fkey_type] || "PkeyValue"
        %}

        @{{field_name.id}} : {{field_type}}?

        def {{field_name.id}}? : {{field_type}}?
          @{{field_name.id}}
        end

        def {{field_name.id}} : {{field_type}}
          {{field_name.id}}? || raise Crecto::AssociationNotLoaded.new("Association `{{field_name.id}}' is not loaded or is nil. Use `{{field_name.id}}?' if the association is nilable.")
        end


        {%
          foreign_key = field_type.id.stringify.split(":")[-1].id.stringify.underscore.downcase + "_id"
          foreign_key = opts[:foreign_key] if opts[:foreign_key]
        %}

        {% unless CRECTO_FIELDS.select { |f| f[:name] == foreign_key.id.stringify }.size > 0 %}
          field {{foreign_key.id}} : {{ fkey_type.id }}
        {% end %}

        def {{field_name.id}}=(val : {{field_type}}?)
          @{{field_name.id}} = val
          return if val.nil?
          @{{foreign_key.id}} = val.pkey_value.as({{ fkey_type.id }})
        end

        CRECTO_ASSOCIATIONS.push({
          association_type: :belongs_to,
          key: {{field_name.id.symbolize}},
          this_klass: {{@type}},
          klass: {{field_type}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model){
            item.as({{@type}}).{{foreign_key.id}}.as(PkeyValue)
          },
          set_association: ->(self_item : Crecto::Model, items : Array(Crecto::Model) | Crecto::Model){
            self_item.as({{@type}}).{{field_name.id}} = items.as(Array(Crecto::Model))[0].as({{field_type}});nil
          },
          through: nil
        })
      end
    end
  end
end
