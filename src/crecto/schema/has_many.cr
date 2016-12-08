module Crecto
  module Schema
    module HasMany
      VALID_HAS_MANY_OPTIONS = [:foreign_key]

      macro has_many(association_name, klass, **opts)        
        property {{association_name.id}} : Array({{klass}})?

        {% foreign_key = @type.id.stringify.downcase + "_id" %}

        {% if opts[:foreign_key] %}
          {% foreign_key = opts[:foreign_key] %}
        {% end %}

        ASSOCIATIONS.push({
          association_type: :has_many,
          key: {{association_name}},
          klass: {{klass}},
          foreign_key: {{foreign_key.symbolize}},
          foreign_key_value: ->(item : Crecto::Model){ item.as({{klass}}).{{foreign_key.id}}.as(Int32 | Int64 | Nil) },
          set_association: ->(self_item : Crecto::Model,items : Array(Crecto::Model)){ self_item.as({{@type}}).{{association_name.id}} = items.map{|i| i.as({{klass}}) };nil }
        })
      end
    end
  end
end