module Crecto
  # Schema is used to define the table name, and inside the schema block define the database field (column) names.
  #
  # example:
  # ```
  # class User < Crecto::Model
  #   schema "users" do
  #     field :name, String
  #   end
  # end
  # ```
  #
  # In the above example, the `User` class will map to the "users" database table.
  # The `:name` field will map to a column in the "users" table named "name", which is a String (varchar)
  #
  # Schema assumes the data store table also has `id`, `created_at` and `updated_at` at fields
  #
  # `field` accepts some optional parameters
  #
  #  * `:virtual` - Will create a `property` on the class, but will not map to a database table
  #  * `:primary_key` - By default "id" is the primary key, use this to change primary key fields
  #
  # By default, Schema assumes `id`, `created_at` and `updated_at` fields exist in the database.
  #
  # The primary key field can be changed from `id` as an option to `field` as stated above.
  #
  # The timestamp fields can be changed or removed by changing:
  #
  # * `set_created_at_field "created_at_field_name"` - use "created_at_field_name" instead of "created_at"
  # * `set_updated_at_field nil` - dont use the updated_at timestamp
  #
  module Schema
    # :nodoc:
    CRECTO_CREATED_AT_FIELD = "created_at"
    # :nodoc:
    CRECTO_UPDATED_AT_FIELD = "updated_at"
    # :nodoc:
    CRECTO_PRIMARY_KEY_FIELD = "id"
    # :nodoc:
    CRECTO_USE_PRIMARY_KEY = true
    # :nodoc:
    CRECTO_PRIMARY_KEY_FIELD_SYMBOL = :id
    # :nodoc:
    CRECTO_PRIMARY_KEY_FIELD_TYPE = "PkeyValue"

    # schema block macro
    macro schema(table_name, **opts, &block)
      include JSON::Serializable

      {% for opt in opts %}
        {% if opt.id.stringify == "primary_key" %}
          CRECTO_USE_PRIMARY_KEY = {{opts[:primary_key]}}
        {% end %}
      {% end %}

      # macro constants
      CRECTO_VALID_FIELD_TYPES = [String, Int64, Int32, Int16, Float32, Float64, Bool, Time, Int32 | Int64, Float32 | Float64, Json, PkeyValue, Array(String), Array(Int64), Array(Int32), Array(Int16), Array(Float32), Array(Float64), Array(Bool), Array(Time), Array(Int32 | Int64), Array(Float32 | Float64), Array(Json), Array(PkeyValue)]
      CRECTO_VALID_FIELD_OPTIONS = [:primary_key, :virtual, :default, :converter]
      CRECTO_FIELDS      = [] of NamedTuple(name: Symbol, type: String, converter: Converter?)

      # Class variables
      @@table_name = {{table_name.id.stringify}}

      {{yield}}

      setup
    end

    # Field definitions macro
    macro field(field, **opts)
      {%
        field_name = field.var
        field_type = field.type
        default_value = field.value.nil? ? opts[:default] : field.value
      %}

      # validate field options
      {% for opt in opts %}
        {% unless CRECTO_VALID_FIELD_OPTIONS.includes?(opt.id.symbolize) %}
          raise Crecto::InvalidOption.new("{{opt}} is not a valid option, must be one of #{CRECTO_VALID_FIELD_OPTIONS.join(", ")}")
        {% end %}
      {% end %}

      # check `primary_key` and `virtual` options
      {% virtual = false %}
      {% primary_key = false %}

      {% if opts.keys.includes?(:primary_key.id) %}
        CRECTO_PRIMARY_KEY_FIELD = {{field_name.id.stringify}}
        CRECTO_PRIMARY_KEY_FIELD_SYMBOL = {{field_name.id.symbolize}}
        CRECTO_PRIMARY_KEY_FIELD_TYPE = {{field_type.id.stringify}}
        {% primary_key = true %}
      {% end %}

      {% if opts.keys.includes?(:virtual.id) %}
        {% virtual = true %}
      {% end %}

      {% if default_value.is_a?(NilLiteral) %}
        @{{field_name.id}} : {{field_type.id}}?
      {% else %}
        @{{field_name.id}} = {{default_value}}
      {% end %}


      {% unless opts[:converter] %}
        check_type!({{field_name.id.symbolize}}, {{field_type}})
      {% end %}

      # cache fields in class variable and macro variable
      {% unless virtual %}
        @@changeset_fields << {{field_name.id.symbolize}}
      {% end %}

      {% unless primary_key %}
        {% CRECTO_FIELDS.push({name: field_name.id.symbolize, type: field_type.id.stringify, converter: opts[:converter]}) %}
        {% unless virtual %}
          CRECTO_MODEL_FIELDS.push({name: {{field_name.id.symbolize}}, type: {{field_type.id.stringify}}})
        {% end %}
      {% end %}
    end

    # Macro to change created_at field name
    macro set_created_at_field(val)
      CRECTO_CREATED_AT_FIELD = {{val}}
    end

    # Macro to change updated_at field name
    macro set_updated_at_field(val)
      CRECTO_UPDATED_AT_FIELD = {{val}}
    end

    # :nodoc:
    macro check_type!(field_name, field_type)
      {% unless CRECTO_VALID_FIELD_TYPES.includes?(field_type) %}
        raise Crecto::InvalidType.new("{{field_name.id}} type must be one of #{CRECTO_VALID_FIELD_TYPES.join(", ")}")
      {% end %}
    end

    # Setup extended methods

    # :nodoc:
    macro setup

      {% json_fields = [] of String %}

      {% mapping = CRECTO_FIELDS.map do |field|
           json_fields.push(field[:name]) if field[:type].id.stringify == "Json"
           field_type = field[:type].id.stringify
           if field[:converter]
            "#{field[:name].id.stringify}: {type: #{field_type.id}, nilable: true, converter: #{field[:converter]}.new}"
           else
            "#{field[:name].id.stringify}: {type: #{field_type.id}, nilable: true}"
           end
         end %}

      {% if CRECTO_USE_PRIMARY_KEY %}
        {% mapping.push(CRECTO_PRIMARY_KEY_FIELD.id.stringify + ": {type: #{CRECTO_PRIMARY_KEY_FIELD_TYPE.id}, nilable: true}") %}
        CRECTO_MODEL_FIELDS.push({name: {{CRECTO_PRIMARY_KEY_FIELD.id.symbolize}}, type: {{CRECTO_PRIMARY_KEY_FIELD_TYPE}}})
        unique_constraint(CRECTO_PRIMARY_KEY_FIELD_SYMBOL)
      {% end %}

      {% unless CRECTO_CREATED_AT_FIELD == nil %}
        {% mapping.push(CRECTO_CREATED_AT_FIELD.id.stringify + ": {type: Time, nilable: true}") %}
        CRECTO_MODEL_FIELDS.push({name: {{CRECTO_CREATED_AT_FIELD.id.symbolize}}, type: "Time"})
      {% end %}

      {% unless CRECTO_UPDATED_AT_FIELD == nil %}
        {% mapping.push(CRECTO_UPDATED_AT_FIELD.id.stringify + ": {type: Time, nilable: true}") %}
        CRECTO_MODEL_FIELDS.push({name: {{CRECTO_UPDATED_AT_FIELD.id.symbolize}}, type: "Time"})
      {% end %}

      DB.mapping({ {{mapping.uniq.join(", ").id}} }, false)

      # Builds fields' cast typed method
      {% for field in CRECTO_FIELDS %}
        def {{field[:name].id}}!
          @{{field[:name].id}}.as({{field[:type].id}})
        end
      {% end %}

      {% for field in json_fields %}
        def {{field.id}}=(val)
          @{{field.id}} = JSON.parse(val.to_json)
        end
      {% end %}

      # Builds a hash from all `CRECTO_FIELDS` defined
      def to_query_hash(include_virtual=false)
        query_hash = {} of Symbol => DbValue | ArrayDbValue

        {% for field in CRECTO_FIELDS %}
          if include_virtual || @@changeset_fields.includes?({{field[:name]}})
            {% if field[:converter] %}
            converter = {{ field[:converter] }}.new
            query_hash[{{field[:name]}}] = self.{{field[:name].id}} ? converter.to_rs(self.{{field[:name].id}}!) : nil
            {% else %}
            query_hash[{{field[:name]}}] = self.{{field[:name].id}}
            query_hash[{{field[:name]}}] = query_hash[{{field[:name]}}].as(Time).to_utc if query_hash[{{field[:name]}}].is_a?(Time) && query_hash[{{field[:name]}}].as(Time).local?
            {% end %}
          end
        {% end %}

        {% unless CRECTO_CREATED_AT_FIELD == nil %}
          query_hash[{{CRECTO_CREATED_AT_FIELD.id.symbolize}}] = self.{{CRECTO_CREATED_AT_FIELD.id}}.nil? ? nil : (self.{{CRECTO_CREATED_AT_FIELD.id}}.as(Time).local? ? self.{{CRECTO_CREATED_AT_FIELD.id}}.as(Time).to_utc : self.{{CRECTO_CREATED_AT_FIELD.id}})
        {% end %}

        {% unless CRECTO_UPDATED_AT_FIELD == nil %}
          query_hash[{{CRECTO_UPDATED_AT_FIELD.id.symbolize}}] = self.{{CRECTO_UPDATED_AT_FIELD.id}}.nil? ? nil : (self.{{CRECTO_UPDATED_AT_FIELD.id}}.as(Time).local? ? self.{{CRECTO_UPDATED_AT_FIELD.id}}.as(Time).to_utc : self.{{CRECTO_UPDATED_AT_FIELD.id}})
        {% end %}

        {% if CRECTO_USE_PRIMARY_KEY %}
          query_hash[{{CRECTO_PRIMARY_KEY_FIELD.id.symbolize}}] = self.{{CRECTO_PRIMARY_KEY_FIELD.id}} unless self.{{CRECTO_PRIMARY_KEY_FIELD.id}}.nil?
        {% end %}

        query_hash
      end

      def update_from_hash(hash)
        {% unless CRECTO_FIELDS.empty? %}
          hash.each do |key, value|
            case key.to_s
            {% for field in CRECTO_FIELDS %}
            when "{{field[:name].id}}"
              if value.to_s.empty?
                @{{field[:name].id}} = nil
              else
                {% if field[:type].id.stringify == "String" %}
                  @{{field[:name].id}} = value.to_s
                {% elsif field[:type].id.stringify == "Int16" %}
                  @{{field[:name].id}} = value.to_i16 if value.to_i16?
                {% elsif field[:type].id.stringify.includes?("Int") %}
                  @{{field[:name].id}} = value.to_i if value.to_i?
                {% elsif field[:type].id.stringify == "PkeyValue" %}
                  @{{field[:name].id}} = value.to_i if value.to_i?
                {% elsif field[:type].id.stringify.includes?("Float") %}
                  @{{field[:name].id}} = value.to_f if value.to_f?
                {% elsif field[:type].id.stringify == "Bool" %}
                  @{{field[:name].id}} = (value == "true")
                {% elsif field[:type].id.stringify == "Json" %}
                  @{{field[:name].id}} = JSON.parse(value)
                {% elsif field[:type].id.stringify == "Time" %}
                  begin
                    @{{field[:name].id}} = Time.parse!(value, "%F %T %z")
                  end
                {% else %}
                  @{{field[:name].id}} = value
                {% end %}
              end
            {% end %}
            end
          end
        {% end %}
      end

      # Returns the value of the primary key field
      def pkey_value
        {% if CRECTO_USE_PRIMARY_KEY %}
        self.{{CRECTO_PRIMARY_KEY_FIELD.id}}
        {% end %}
      end

      {% if CRECTO_USE_PRIMARY_KEY %}
      def {{CRECTO_PRIMARY_KEY_FIELD.id }}
        @{{CRECTO_PRIMARY_KEY_FIELD.id}}.not_nil!
      end

      def {{CRECTO_PRIMARY_KEY_FIELD.id }}=(val)
        @{{CRECTO_PRIMARY_KEY_FIELD.id}} = val
      end
      {% end %}

      def updated_at
        @{{CRECTO_UPDATED_AT_FIELD.id}}
      end

      def created_at
        @{{CRECTO_CREATED_AT_FIELD.id}}
      end

      def updated_at_to_now
        {% unless CRECTO_UPDATED_AT_FIELD == nil %}
          self.{{CRECTO_UPDATED_AT_FIELD.id}} = Time.utc
        {% end %}
      end

      def created_at_to_now
        {% unless CRECTO_CREATED_AT_FIELD == nil %}
          self.{{CRECTO_CREATED_AT_FIELD.id}} = Time.utc
        {% end %}
      end

      def cast(**attributes : **T) forall T
        \{% for field in CRECTO_FIELDS.select { |field| T.keys.includes?(field[:name].id) } %}
           if attributes.has_key?(\{{ field[:name] }})
             self.\{{ field[:name].id }} = attributes[\{{ field[:name] }}]
           end
        \{% end %}
      end

      def cast(attributes : NamedTuple, whitelist : Tuple = attributes.keys)
        cast(attributes.to_h, whitelist.to_a)
      end

      def cast(attributes : Hash(String, T), whitelist : Array(String | Symbol) = attributes.keys) forall T
        {% if CRECTO_FIELDS.size > 0 %}
          cast_attributes = {} of String => Union({{ CRECTO_FIELDS.map { |field| field[:type].id }.splat }})

          attributes.each do |key, value|
            cast_attributes[key] = value
          end

          {% for field in CRECTO_FIELDS %}
             if whitelist.includes?({{ field[:name] }}) && attributes.has_key?({{ field[:name] }})
               self.{{ field[:name].id }} = cast_attributes[{{ field[:name] }}].as({{ field[:type].id }})
             end
          {% end %}
        {% end %}
      end

      def cast(attributes : Hash(String, T), whitelist : Array(String) = attributes.keys) forall T
        {% if CRECTO_FIELDS.size > 0 %}
          cast_attributes = {} of String => Union({{ CRECTO_FIELDS.map { |field| field[:type].id }.splat }})

          attributes.each do |key, value|
            cast_attributes[key] = value
          end

          {% for field in CRECTO_FIELDS %}
            if whitelist.includes?({{ field[:name].id.stringify }}) && attributes.has_key?({{ field[:name].id.stringify }})
              self.{{ field[:name].id }} = cast_attributes[{{ field[:name].id.stringify }}].as({{ field[:type].id }})
            end
          {% end %}
        {% end %}
      end
    end
  end
end
