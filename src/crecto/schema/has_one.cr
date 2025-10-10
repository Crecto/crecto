module Crecto
  module Schema
    # This hasn't been done yet
    module HasOne
      VALID_HAS_ONE_OPTIONS = [:foreign_key]

      macro has_one(association_name, klass, **opts)
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
          foreign_key = @type.id.stringify.split(":")[-1].id.stringify.underscore.downcase + "_id"
          foreign_key = opts[:foreign_key] if opts[:foreign_key]
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


        CRECTO_ASSOCIATIONS.push({
          association_type: :has_one,
          key: {{association_name}},
          this_klass: {{@type}},
          klass: {{klass}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model) {
            item.as({{@type}}).pkey_value.as(PkeyValue)
          },
          set_association: ->(self_item : Crecto::Model, item: Array(Crecto::Model) | Crecto::Model) {
            if item.is_a?(Array)
              array_items = item.as(Array(Crecto::Model))
              # Safe array access with bounds checking - take first valid item
              if array_items.size > 0
                target_item = array_items[0]?
                if target_item
                  self_item.as({{@type}}).{{association_name.id}} = target_item.as({{klass}})
                else
                  self_item.as({{@type}}).{{association_name.id}} = nil
                end
              else
                self_item.as({{@type}}).{{association_name.id}} = nil
              end
            else
              # Single item case
              if item.nil?
                self_item.as({{@type}}).{{association_name.id}} = nil
              else
                self_item.as({{@type}}).{{association_name.id}} = item.as({{klass}})
              end
            end
            nil
          },
          through: nil
        })
      end
    end
  end
end
