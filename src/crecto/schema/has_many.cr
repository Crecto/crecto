module Crecto
  module Schema
    module HasMany
      macro has_many(association_name, klass, **opts)
        {% unless @type.has_constant? "CRECTO_ASSOCIATIONS" %}
          Crecto::Schema::Associations.setup_associations
        {% end %}

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

        CRECTO_ASSOCIATIONS.push({
          association_type: :has_many,
          key: {{association_name}},
          this_klass: {{@type}},
          klass: {{klass}},
          foreign_key: {{foreign_key.id.symbolize}},
          foreign_key_value: ->(item : Crecto::Model){
            # For has_many, the item could be either the parent (User) or child (Post)
            # If it's the parent type, return the primary key
            # If it's the child type, return the foreign key value
            {% if opts[:through] %}
              item.as({{@type}}).pkey_value.as(PkeyValue)
            {% else %}
              # Check if item is the parent class (this_klass)
              if item.is_a?({{@type}})
                # Parent class: return primary key for matching
                item.as({{@type}}).pkey_value.as(PkeyValue)
              else
                # Child class: return foreign key value (e.g. post.user_id)
                item.to_query_hash[{{foreign_key.id.symbolize}}]?.as(PkeyValue?)
              end
            {% end %}
          },
          set_association: ->(self_item : Crecto::Model, items : Array(Crecto::Model) | Crecto::Model){
            if items.is_a?(Array)
              array_items = items.as(Array(Crecto::Model))
              # Safe array access with bounds checking - ensure all items are convertible to {{klass}}
              typed_items = array_items.map { |i| i.as({{klass}}) }
              self_item.as({{@type}}).{{association_name.id}} = typed_items
            else
              # Single item case - wrap in array if not nil
              if items.nil?
                self_item.as({{@type}}).{{association_name.id}} = Array({{klass}}).new
              else
                typed_item = items.as({{klass}})
                self_item.as({{@type}}).{{association_name.id}} = [typed_item]
              end
            end
            nil
          },
          through: {{through}}
        })
      end
    end
  end
end
