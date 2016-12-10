module Crecto
  module Schema
    module BelongsTo
      VALID_BELONGS_TO_OPTIONS = [:foreign_key]

      macro belongs_to(association_name, klass, **opts)
        property {{association_name.id}} : {{klass}}?

        {% 
          foreign_key = klass.id.stringify.underscore.downcase + "_id"

          if opts[:foreign_key]
            foreign_key = opts[:foreign_key]
          end 
        %}

        def {{association_name.id}}=(val : {{klass}}?)
          @{{association_name.id}} = val
          return if val.nil?
          @{{foreign_key.id}} = val.pkey_value.as(Int32)
        end

        ASSOCIATIONS.push({
          association_type: :belongs_to,
          key: {{association_name}},
          this_klass: {{@type}},
          klass: {{klass}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model){ item.as({{@type}}).{{foreign_key.id}}.as(PkeyValue) },
          set_association: ->(self_item : Crecto::Model, items : Array(Crecto::Model)){ self_item.as({{@type}}).{{association_name.id}} = items[0].as({{klass}});nil }
        })
      end
    end
  end
end
