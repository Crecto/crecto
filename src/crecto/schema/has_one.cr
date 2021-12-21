module Crecto
  module Schema
    # This hasn't been done yet
    module HasOne
      VALID_HAS_ONE_OPTIONS = [:foreign_key]

      macro has_one(association, **opts)
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
          foreign_key = @type.id.stringify.split(":")[-1].id.stringify.underscore.downcase + "_id"
          foreign_key = opts[:foreign_key] if opts[:foreign_key]
        %}

        {% on_replace = opts[:dependent] || opts[:on_replace] %}

        {% if on_replace && on_replace == :destroy %}
          self.add_destroy_association({{field_name.id.symbolize}})
        {% end %}


        {% if on_replace && on_replace == :nullify %}
          self.add_nullify_association({{field_name.id.symbolize}})
        {% end %}

        def {{field_name.id}}=(val : {{field_type}}?)
          @{{field_name.id}} = val
          return if val.nil?
          @{{foreign_key.id}} = val.pkey_value.as({{ fkey_type.id }})
        end


        CRECTO_ASSOCIATIONS.push({
          association_type: "has_one",
          key: {{field_name.id.stringify}},
          this_klass: {{@type}},
          klass: {{field_type}},
          foreign_key: {{foreign_key.id.stringify}},
          foreign_key_value: ->(item : Crecto::Model) {
            item.as({{field_type}}).{{foreign_key.id}}.as(PkeyValue)
          },
          set_association: ->(self_item : Crecto::Model, item: Array(Crecto::Model) | Crecto::Model) {
            self_item.as({{@type}}).{{field_name.id}} = item.as({{field_type}})
            nil
          },
          through: nil
        })
      end
    end
  end
end
