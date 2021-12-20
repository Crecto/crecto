module Crecto
  module Schema
    module HasMany
      macro has_many(association, **opts)
        {% unless @type.has_constant? "CRECTO_ASSOCIATIONS" %}
          Crecto::Schema::Associations.setup_associations
        {% end %}

        {%
          field_name = association.var
          field_type = association.type
        %}

        @{{field_name.id}} : Array({{field_type}})?

        def {{field_name.id}}? : Array({{field_type}})?
          @{{field_name.id}}
        end

        def {{field_name.id}} : Array({{field_type}})
          @{{field_name.id}} || raise Crecto::AssociationNotLoaded.new("Association `{{field_name.id}}' not loaded")
        end

        def {{field_name.id}}=(val : Array({{field_type}}))
          @{{field_name.id}} = val
        end


        {%
          through = opts[:through] || nil
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

        CRECTO_ASSOCIATIONS.push({
          association_type: "has_many",
          key: {{field_name.id.stringify}},
          this_klass: {{@type}},
          klass: {{field_type}},
          foreign_key: {{foreign_key.id.stringify}},
          foreign_key_value: ->(item : Crecto::Model){
            {% if opts[:through] %}
              item.as({{field_type}}).id.as(PkeyValue)
            {% else %}
              item.as({{field_type}}).{{foreign_key.id}}.as(PkeyValue)
            {% end %}
          },
          set_association: ->(self_item : Crecto::Model, items : Array(Crecto::Model) | Crecto::Model){
            self_item.as({{@type}}).{{field_name.id}} = items.as(Array(Crecto::Model)).map{|i| i.as({{field_type}}) }
            nil
          },
          through: {{through.id.stringify}}
        })
      end
    end
  end
end
