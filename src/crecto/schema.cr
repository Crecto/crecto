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
  # * `created_at_field "created_at_field_name"` - use "created_at_field_name" instead of "created_at"
  # * `updated_at_field nil` - dont use the updated_at timestamp
  #
  module Schema
    # :nodoc:
    CREATED_AT_FIELD = "created_at"
    # :nodoc:
    UPDATED_AT_FIELD = "updated_at"
    # :nodoc:
    PRIMARY_KEY_FIELD = "id"
    # :nodoc:
    PRIMARY_KEY_FIELD_SYMBOL = :id
    # :nodoc:
    PRIMARY_KEY_FIELD_TYPE = "PkeyValue"
    # :nodoc:
    ASSOCIATIONS = Array(NamedTuple(association_type: Symbol,
    key: Symbol,
    this_klass: Model.class,
    klass: Model.class,
    foreign_key: Symbol,
    foreign_key_value: Proc(Model, PkeyValue),
    set_association: Proc(Model, (Array(Crecto::Model) | Model), Nil),
    through: Symbol?)).new

    # schema block macro
    macro schema(table_name, &block)

      # macro constants
      VALID_FIELD_TYPES = [String, Int64, Int32, Int16, Float32, Float64, Bool, Time, Int32 | Int64, Float32 | Float64, Json, PkeyValue]
      VALID_FIELD_OPTIONS = [:primary_key, :virtual]
      FIELDS = [] of NamedTuple(name: Symbol, type: String)

      # Class variables
      @@table_name = {{table_name.id.stringify}}

      {{yield}}

      setup
    end

    # Field definitions macro
    macro field(field_name, field_type, **opts)
      # validate field options
      {% for opt in opts %}
        {% unless VALID_FIELD_OPTIONS.includes?(opt.id.symbolize) %}
          raise Crecto::InvalidOption.new("{{opt}} is not a valid option, must be one of #{VALID_FIELD_OPTIONS.join(", ")}")
        {% end %}
      {% end %}

      # check `primary_key` and `virtual` options
      {% virtual = false %}
      {% primary_key = false %}
      {% if opts[:primary_key] %}
        PRIMARY_KEY_FIELD = {{field_name.id.stringify}}
        PRIMARY_KEY_FIELD_SYMBOL = {{field_name.id.symbolize}}
        PRIMARY_KEY_FIELD_TYPE = {{field_type.id.stringify}}
        {% primary_key = true %}
      {% elsif opts[:virtual] %}
        {% virtual = true %}
      {% end %}

      check_type!({{field_name}}, {{field_type}})

      # cache fields in class variable and macro variable
      {% unless virtual %}
        @@changeset_fields << {{field_name}}
      {% end %}

      {% unless primary_key %}
        {% FIELDS.push({name: field_name, type: field_type}) %}
        {% unless virtual %}
          MODEL_FIELDS.push({name: {{field_name}}, type: {{field_type.id.stringify}}})
        {% end %}
      {% end %}
    end

    # Macro to change created_at field name
    macro created_at_field(val)
      CREATED_AT_FIELD = {{val}}
    end

    # Macro to chnage updated_at field name
    macro updated_at_field(val)
      UPDATED_AT_FIELD = {{val}}
    end

    # :nodoc:
    macro check_type!(field_name, field_type)
      {% unless VALID_FIELD_TYPES.includes?(field_type) %}
        raise Crecto::InvalidType.new("{{field_name}} type must be one of #{VALID_FIELD_TYPES.join(", ")}")
      {% end %}
    end

    # Setup extended methods

    # :nodoc:
    macro setup

      {% json_fields = [] of String %}

      {% mapping = FIELDS.map do |field|
           json_fields.push(field[:name]) if field[:type].id.stringify == "Json"
           field_type = field[:type].id == "Int64" || field[:type].id == "Int32" ? "PkeyValue" : field[:type].id.stringify
           "#{field[:name].id.stringify}: {type: #{field_type.id}, nilable: true}"
         end %}

      {% mapping.push(PRIMARY_KEY_FIELD.id.stringify + ": {type: #{PRIMARY_KEY_FIELD_TYPE.id}, nilable: true}") %}
      MODEL_FIELDS.push({name: {{PRIMARY_KEY_FIELD.id.symbolize}}, type: {{PRIMARY_KEY_FIELD_TYPE}}})

      {% unless CREATED_AT_FIELD == nil %}
        {% mapping.push(CREATED_AT_FIELD.id.stringify + ": {type: Time, nilable: true}") %}
        MODEL_FIELDS.push({name: {{CREATED_AT_FIELD.id.symbolize}}, type: "Time"})
      {% end %}

      {% unless UPDATED_AT_FIELD == nil %}
        {% mapping.push(UPDATED_AT_FIELD.id.stringify + ": {type: Time, nilable: true}") %}
        MODEL_FIELDS.push({name: {{UPDATED_AT_FIELD.id.symbolize}}, type: "Time"})
      {% end %}

      DB.mapping({ {{mapping.uniq.join(", ").id}} }, false)
      JSON.mapping({ {{mapping.uniq.join(", ").id}} })

      {% for field in json_fields %}
        def {{field.id}}=(val)
          json = Crecto::Helpers.jsonize(val)
          @{{field.id}} = JSON::Any.new(json)
        end
      {% end %}

      # Builds a hash from all `FIELDS` defined
      def to_query_hash
        query_hash = {} of Symbol => DbValue

        {% for field in FIELDS %}
          if @@changeset_fields.includes?({{field[:name]}})
            query_hash[{{field[:name]}}] = self.{{field[:name].id}}
            query_hash[{{field[:name]}}] = query_hash[{{field[:name]}}].as(Time).to_utc if query_hash[{{field[:name]}}].is_a?(Time) && query_hash[{{field[:name]}}].as(Time).local?
          end
        {% end %}

        {% unless CREATED_AT_FIELD == nil %}
          query_hash[{{CREATED_AT_FIELD.id.symbolize}}] = self.{{CREATED_AT_FIELD.id}}.nil? ? nil : (self.{{CREATED_AT_FIELD.id}}.as(Time).local? ? self.{{CREATED_AT_FIELD.id}}.as(Time).to_utc : self.{{CREATED_AT_FIELD.id}})
        {% end %}

        {% unless UPDATED_AT_FIELD == nil %}
          query_hash[{{UPDATED_AT_FIELD.id.symbolize}}] = self.{{UPDATED_AT_FIELD.id}}.nil? ? nil : (self.{{UPDATED_AT_FIELD.id}}.as(Time).local? ? self.{{UPDATED_AT_FIELD.id}}.as(Time).to_utc : self.{{UPDATED_AT_FIELD.id}})
        {% end %}

        query_hash[{{PRIMARY_KEY_FIELD.id.symbolize}}] = self.{{PRIMARY_KEY_FIELD.id}} unless self.{{PRIMARY_KEY_FIELD.id}}.nil?

        query_hash
      end

      def update_from_hash(hash : Hash(String, String))
        hash.each do |key, value|
          case key.to_s
          {% for field in FIELDS %}
          when "{{field[:name].id}}"
            {% if field[:type].id.stringify == "String" %}
              @{{field[:name].id}} = value
            {% elsif field[:type].id.stringify == "Int16" %}
              @{{field[:name].id}} = value.to_i16 if value.to_i16?
            {% elsif field[:type].id.stringify.includes?("Int") %}
              @{{field[:name].id}} = value.to_i if value.to_i?
            {% elsif field[:type].id.stringify.includes?("Float") %}
              @{{field[:name].id}} = value.to_f if value.to_f?
            {% elsif field[:type].id.stringify == "Bool" %}
              @{{field[:name].id}} = (value == "true")
            # {% elsif field[:type].id.stringify == "Time" %}
            #   @{{field[:name].id}} = Time.parse(value)
            {% end %}
          {% end %}
          end
        end
      end

      # Returns the value of the primary key field
      def pkey_value
        self.{{PRIMARY_KEY_FIELD.id}}
      end

      def update_primary_key(val)
        self.{{PRIMARY_KEY_FIELD.id}} = val
      end

      def updated_at_value
        self.{{UPDATED_AT_FIELD.id}}
      end

      def created_at_value
        self.{{CREATED_AT_FIELD.id}}
      end

      def updated_at_to_now
        {% unless UPDATED_AT_FIELD == nil %}
          self.{{UPDATED_AT_FIELD.id}} = Time.utc_now
        {% end %}
      end

      def created_at_to_now
        {% unless CREATED_AT_FIELD == nil %}
          self.{{CREATED_AT_FIELD.id}} = Time.utc_now
        {% end %}
      end

    end
  end
end
