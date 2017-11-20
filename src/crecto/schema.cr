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
    # :nodoc:
    CRECTO_ASSOCIATIONS = Array(NamedTuple(association_type: Symbol,
    key: Symbol,
    this_klass: Model.class,
    klass: Model.class,
    foreign_key: Symbol,
    foreign_key_value: Proc(Model, PkeyValue),
    set_association: Proc(Model, (Array(Crecto::Model) | Model), Nil),
    through: Symbol?)).new

    # schema block macro
    macro schema(table_name, **opts, &block)
      {% for opt in opts %}
        {% if opt.id.stringify == "primary_key" %}
          CRECTO_USE_PRIMARY_KEY = {{opts[:primary_key]}}
        {% end %}
      {% end %}

      # macro constants
      CRECTO_VALID_FIELD_TYPES = [String, Int64, Int32, Int16, Float32, Float64, Bool, Time, Int32 | Int64, Float32 | Float64, Json, PkeyValue, Array(String), Array(Int64), Array(Int32), Array(Int16), Array(Float32), Array(Float64), Array(Bool), Array(Time), Array(Int32 | Int64), Array(Float32 | Float64), Array(Json), Array(PkeyValue)]
      CRECTO_VALID_FIELD_OPTIONS = [:primary_key, :virtual, :default]
      CRECTO_FIELDS      = [] of NamedTuple(name: Symbol, type: String)
      CRECTO_ENUM_FIELDS = [] of NamedTuple(name: Symbol, type: String, column_name: String, column_type: String)

      # Class variables
      @@table_name = {{table_name.id.stringify}}

      {{yield}}

      setup
    end

    # Field definitions macro
    macro field(field_name, field_type, **opts)
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

      {% if opts.keys.includes?(:default.id) %}
        @{{field_name.id}} = {{opts[:default]}}
      {% end %}

      check_type!({{field_name}}, {{field_type}})

      # cache fields in class variable and macro variable
      {% unless virtual %}
        @@changeset_fields << {{field_name}}
      {% end %}

      {% unless primary_key %}
        {% CRECTO_FIELDS.push({name: field_name, type: field_type}) %}
        {% unless virtual %}
          CRECTO_MODEL_FIELDS.push({name: {{field_name}}, type: {{field_type.id.stringify}}})
        {% end %}
      {% end %}
    end

    # Enum field definition macro.
    # `opts` can include `column_name` to set the name of the backing column
    # in the database and `column_type` to set the type of that column (String
    # and all Int types are currently supported)
    macro enum_field(field_name, field_type, **opts)
      {%
        column_type = String
        column_type = opts[:column_type] if opts[:column_type]
        column_name = "#{field_name.id}_#{column_type.id.stringify.downcase.id}"
        column_name = opts[:column_name] if opts[:column_name]
      %}

      field({{column_name.id.symbolize}}, {{column_type}})

      {% CRECTO_ENUM_FIELDS.push({name: field_name, type: field_type, column_name: column_name, column_type: column_type}) %}
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
        raise Crecto::InvalidType.new("{{field_name}} type must be one of #{CRECTO_VALID_FIELD_TYPES.join(", ")}")
      {% end %}
    end

    # Setup extended methods

    # :nodoc:
    macro setup

      {% json_fields = [] of String %}

      {% mapping = CRECTO_FIELDS.map do |field|
           json_fields.push(field[:name]) if field[:type].id.stringify == "Json"
           field_type = field[:type].id == "Int64" || field[:type].id == "Int32" ? "PkeyValue" : field[:type].id.stringify
           "#{field[:name].id.stringify}: {type: #{field_type.id}, nilable: true}"
         end %}

      {% if CRECTO_USE_PRIMARY_KEY %}
        {% mapping.push(CRECTO_PRIMARY_KEY_FIELD.id.stringify + ": {type: #{CRECTO_PRIMARY_KEY_FIELD_TYPE.id}, nilable: true}") %}
        CRECTO_MODEL_FIELDS.push({name: {{CRECTO_PRIMARY_KEY_FIELD.id.symbolize}}, type: {{CRECTO_PRIMARY_KEY_FIELD_TYPE}}})
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
      JSON.mapping({ {{mapping.uniq.join(", ").id}} })

      {% for field in json_fields %}
        def {{field.id}}=(val)
          json = Crecto::Helpers.jsonize(val)
          @{{field.id}} = JSON::Any.new(json)
        end
      {% end %}

      {% for enum_field in CRECTO_ENUM_FIELDS %}
        {%
          field_name = enum_field[:name].id
          field_type = enum_field[:type].id
          column_name = enum_field[:column_name].id
          column_type = enum_field[:column_type].id
        %}
        {% if column_type.stringify == "String" %}
          def {{field_name}} : {{field_type}}
            @{{field_name}} ||= {{field_type}}.parse(@{{column_name}}.to_s)
          end

          def {{field_name}}=(val : {{field_type}})
            @{{field_name}} = val
            @{{column_name}} = val.to_s
          end

        {% elsif column_type.stringify.includes?("Int") %}
          def {{field_name}} : {{field_type}}
            @{{field_name}} ||= {{field_type}}.new(@{{column_name}}.not_nil!.to_i32)
          end

          def {{field_name}}=(val : {{field_type}})
            @{{field_name}} = val
            @{{column_name}} = val.value
          end
        {% end %}
      {% end %}


      # Builds a hash from all `CRECTO_FIELDS` defined
      def to_query_hash(include_virtual=false)
        query_hash = {} of Symbol => DbValue | ArrayDbValue

        {% for field in CRECTO_FIELDS %}
          if include_virtual || @@changeset_fields.includes?({{field[:name]}})
            query_hash[{{field[:name]}}] = self.{{field[:name].id}}
            query_hash[{{field[:name]}}] = query_hash[{{field[:name]}}].as(Time).to_utc if query_hash[{{field[:name]}}].is_a?(Time) && query_hash[{{field[:name]}}].as(Time).local?
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

      def update_from_hash(hash : Hash(String, DbValue))
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
              {% elsif field[:type].id.stringify.includes?("Float") %}
                @{{field[:name].id}} = value.to_f if value.to_f?
              {% elsif field[:type].id.stringify == "Bool" %}
                @{{field[:name].id}} = (value == "true")
              {% elsif field[:type].id.stringify == "Json" %}
                @{{field[:name].id}} = JSON.parse(value)
              {% elsif field[:type].id.stringify == "Time" %}
                begin
                  @{{field[:name].id}} = Time.parse(value, "%F %T %z")
                end
              {% end %}
            end
          {% end %}
          end
        end
      end

      # Returns the value of the primary key field
      def pkey_value
        {% if CRECTO_USE_PRIMARY_KEY %}
        self.{{CRECTO_PRIMARY_KEY_FIELD.id}}
        {% end %}
      end

      def update_primary_key(val)
        self.{{CRECTO_PRIMARY_KEY_FIELD.id}} = val
      end

      def updated_at_value
        self.{{CRECTO_UPDATED_AT_FIELD.id}}
      end

      def created_at_value
        self.{{CRECTO_CREATED_AT_FIELD.id}}
      end

      def updated_at_to_now
        {% unless CRECTO_UPDATED_AT_FIELD == nil %}
          self.{{CRECTO_UPDATED_AT_FIELD.id}} = Time.utc_now
        {% end %}
      end

      def created_at_to_now
        {% unless CRECTO_CREATED_AT_FIELD == nil %}
          self.{{CRECTO_CREATED_AT_FIELD.id}} = Time.utc_now
        {% end %}
      end

    end
  end
end
