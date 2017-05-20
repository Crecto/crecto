module Crecto
  module Schema
    # This hasn't been done yet
    module HasOne
      VALID_HAS_ONE_OPTIONS = [:foreign_key]

      macro has_one(association_name, klass, **opts)
        @{{association_name.id}} : {{klass}}?

        def {{association_name.id}}? : {{klass}}?
          @{{association_name.id}}
        end

        def {{association_name.id}} : {{klass}}
          {{association_name.id}}? || raise Crecto::AssociationNotLoaded.new("Association `{{association_name.id}}' is not loaded or is nil. Use `{{association_name.id}}?' if the association is nilable.")
        end


        {%
          foreign_key = @type.id.stringify.underscore.downcase + "_id"

          if opts[:foreign_key]
            foreign_key = opts[:foreign_key]
          end
        %}

        {% on_replace = opts[:dependent] || opts[:on_replace] %}

        {% if on_replace && on_replace == :destroy %}
          self.add_destroy_association({{association_name.id.symbolize}})
        {% end %}


        {% if on_replace && on_replace == :nullify %}
          self.add_nullify_association({{association_name.id.symbolize}})
        {% end %}

        def {{association_name.id}}=(val : {{klass}}?)
          @{{association_name.id}} = val
          return if val.nil?
          @{{foreign_key.id}} = val.pkey_value.as(PkeyValue)
        end


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
