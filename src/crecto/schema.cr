module Crecto
  # Schema is used to define the table name, and inside the schema block define the database field (column) names.
  #
  # Include this module and then define `schema` and `field` in your class
  #
  # example:
  # ```
  # class Uer
  #   include Crecto::Schema
  #
  #   schema "users" do
  #     field :name, String
  #   end
  # end
  # ```
  #
  # In the above example, the `User` class will map to the "users" database table.
  # The `:name` field will map to a column in the "users" table named "name", which is a String (varchar)
  #
  # Schema assumes the data store table also has `id`, `created-at` and `updated_at` at fields
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

    # Class constants
    CREATED_AT_FIELD = "created_at"
    UPDATED_AT_FIELD = "updated_at"
    PRIMARY_KEY_FIELD = "id"

    # schema block macro
    macro schema(table_name, &block)
      include Crecto::Schema::HasMany
      include Crecto::Schema::HasOne
      include Crecto::Schema::BelongsTo

      # macro constants
      VALID_FIELD_TYPES = [String, Int64, Int32, Float64, Bool, Time]
      VALID_FIELD_OPTIONS = [:primary_key, :virtual]
      FIELDS = [] of String

      # Class variables
      @@table_name = {{table_name.id.stringify}}
      @@changeset_fields = [] of Symbol
      @@initial_values = {} of Symbol => DbValue

      # Instance properties
      property initial_values : Hash(Symbol, DbValue)?

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
      virtual = false
      {% if opts[:primary_key] %}
        PRIMARY_KEY_FIELD = {{field_name.id.stringify}}
      {% elsif opts[:virtual] %}
        virtual = true
      {% end %}

      check_type!({{field_name}}, {{field_type}})

      # cache fields in class variable and macro variable
      @@changeset_fields << {{field_name}} unless virtual
      {% FIELDS << field_name %}

      # set `property`
      {% if field_type.id == "Int64" %}
        property {{field_name.id}} : (Int64 | Int32 | Nil)
      {% else %}
        property {{field_name.id}} : {{field_type}}?
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
    # Check the field type is valid
    macro check_type!(field_name, field_type)
      {% unless VALID_FIELD_TYPES.includes?(field_type) %}
        raise Crecto::InvalidType.new("{{field_name}} type must be one of #{VALID_FIELD_TYPES.join(", ")}")
      {% end %}
    end

    # Setup extended methods
    macro setup
      extend BuildFromSQL

      property {{PRIMARY_KEY_FIELD.id}} : (Int32 | Int64 | Nil)

      {% unless CREATED_AT_FIELD == nil %}
        property {{CREATED_AT_FIELD.id}} : Time?
      {% end %}

      {% unless UPDATED_AT_FIELD == nil %}
        property {{UPDATED_AT_FIELD.id}} : Time?
      {% end %}

      # Builds a hash from all `FIELDS` defined
      def to_query_hash
        query_hash = {} of Symbol => DbValue

        {% for field in FIELDS %}
          if self.{{field.id}} && @@changeset_fields.includes?({{field}})
            query_hash[{{field}}] = self.{{field.id}}
            query_hash[{{field}}] = query_hash[{{field}}].as(Time).to_utc if query_hash[{{field}}].is_a?(Time)
          end
        {% end %}

        {% unless CREATED_AT_FIELD == nil %}
          query_hash[{{CREATED_AT_FIELD.id.symbolize}}] = self.{{CREATED_AT_FIELD.id}}.nil? ? nil : self.{{CREATED_AT_FIELD.id}}.as(Time).to_utc
        {% end %}

        {% unless UPDATED_AT_FIELD == nil %}
          query_hash[{{UPDATED_AT_FIELD.id.symbolize}}] = self.{{UPDATED_AT_FIELD.id}}.nil? ? nil : self.{{UPDATED_AT_FIELD.id}}.as(Time).to_utc
        {% end %}

        query_hash
      end

      # Returns the value of the primary key field
      def pkey_value
        self.{{PRIMARY_KEY_FIELD.id}}.as(Int32)
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
          self.{{UPDATED_AT_FIELD.id}} = Time.now
        {% end %}
      end

      def created_at_to_now
        {% unless CREATED_AT_FIELD == nil %}
          self.{{CREATED_AT_FIELD.id}} = Time.now
        {% end %}
      end

      # Return the primary key field as a String
      def self.primary_key_field
        PRIMARY_KEY_FIELD
      end

      def self.created_at_field
        CREATED_AT_FIELD
      end

      def self.updated_at_field
        UPDATED_AT_FIELD
      end

      # Class method to get the `changeset_fields`
      def self.changeset_fields
        @@changeset_fields
      end

      # Class method to get the table name
      def self.table_name
        @@table_name
      end

    end
  end
end
