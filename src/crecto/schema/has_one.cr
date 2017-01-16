module Crecto
  module Schema
    # This hasn't been done yet
    module HasOne
      VALID_HAS_ONE_OPTIONS = [:foreign_key]

      macro has_one(association_name, klass, **opts)
        property {{association_name.id}} : {{klass}}?

        {%
          foreign_key = @type.id.stringify.underscore.downcase + "_id"

          if opts[:foreign_key]
            foreign_key = opts[:foreign_key]
          end
        %}

        ASSOCIATIONS.push({
          association_type: :has_one,
          key: {{association_name}},
          this_klass: {{@type}},
          klass: {{klass}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model) {
            item.as({{klass}}).{{foreign_key.id}}.as(PkeyValue)
          },
          set_association: ->(self_item : Crecto::Model, item: Array(Crecto::Model) | Crecto::Model) {
            self_item.as({{@type}}).{{association_name.id}} = item.as({{klass}})
            nil
          },
          through: nil
        })
      end
    end
  end
end
