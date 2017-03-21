module Crecto
  module Schema
    module HasMany
      macro has_many(association_name, klass, **opts)

        property {{association_name.id}} : Array({{klass}})?

        {%
          through = opts[:through] || nil
          foreign_key = @type.id.stringify.underscore.downcase + "_id"

          if opts[:foreign_key]
            foreign_key = opts[:foreign_key]
          end
        %}

        {%
          on_replace = opts[:dependent] || opts[:on_replace]

          if on_replace
            if on_replace == :destroy
              DESTROY_ASSOCIATIONS << association_name.id.symbolize
            elsif on_replace == :nilify
              NILIFY_ASSOCIATIONS << association_name.id.symbolize
            end
          end
        %}

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
