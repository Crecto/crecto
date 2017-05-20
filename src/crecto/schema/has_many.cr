module Crecto
  module Schema
    module HasMany
      macro has_many(association_name, klass, **opts)
        @{{association_name.id}} : Array({{klass}})?

        def {{association_name.id}}? : Array({{klass}})?
          @{{association_name.id}}
        end

        def {{association_name.id}} : Array({{klass}})
          @{{association_name.id}} || raise Crecto::AssociationNotLoaded.new("Association `{{association_name.id}}' not loaded")
        end

        def {{association_name.id}}=(val : Array({{klass}}))
          @{{association_name.id}} = val
        end


        {%
          through = opts[:through] || nil
          foreign_key = @type.id.stringify.underscore.downcase + "_id"
          foreign_key = opts[:foreign_key] if opts[:foreign_key]
        %}

        {% on_replace = opts[:dependent] || opts[:on_replace] %}

        {% if on_replace && on_replace == :destroy %}
          self.add_destroy_association({{association_name.id.symbolize}})
        {% end %}


        {% if on_replace && on_replace == :nullify %}
          self.add_nullify_association({{association_name.id.symbolize}})
        {% end %}

        ASSOCIATIONS.push({
          association_type: :has_many,
          key: {{association_name}},
          this_klass: {{@type}},
          klass: {{klass}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model){
            {% if opts[:through] %}
              item.as({{klass}}).id
            {% else %}
              item.as({{klass}}).{{foreign_key.id}}.as(PkeyValue)
            {% end %}
          },
          set_association: ->(self_item : Crecto::Model, items : Array(Crecto::Model) | Crecto::Model){
            self_item.as({{@type}}).{{association_name.id}} = items.as(Array(Crecto::Model)).map{|i| i.as({{klass}}) }
            nil
          },
          through: {{through}}
        })
      end
    end
  end
end
