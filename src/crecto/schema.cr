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
  # `field` accepts some optional parameters
  #
  #  * `:virtual` - Will create a `property` on the class, but will not map to a database table
  #  * `:primary_key` - By default "id" is the primary key, use this to change primary key fields
  #
  module Schema
    include Crecto::Schema::HasMany
    include Crecto::Schema::HasOne
    include Crecto::Schema::BelongsTo

    VALID_FIELD_TYPES = [String, Int32, Float64, Bool, Time]
    VALID_FIELD_OPTIONS = [:primary_key, :virtual]

    property id : Int32?
    property created_at : Time?
    property updated_at : Time?
    property initial_values : Hash(Symbol, Int32 | Int64 | String | Float64 | Bool | Time | Nil)?

    # schema block macro
    macro schema(table_name, &block)
      FIELDS = [] of String
      PRIMARY_KEY = "id"
      
      @@table_name = {{table_name.id.stringify}}
      @@primary_key = "id"
      @@changeset_fields = [] of Symbol
      @@initial_values = {} of Symbol => Int32 | Int64 | String | Float64 | Bool | Time | Nil

      {{yield}}

      setup
    end

    # Field definitions macro
    macro field(field_name, field_type, **opts)
      {% for opt in opts %}
        {% unless VALID_FIELD_OPTIONS.includes?(opt.id.symbolize) %}
          raise Crecto::InvalidOption.new("{{opt}} is not a valid option, must be one of #{VALID_FIELD_OPTIONS.join(", ")}")
        {% end %}
      {% end %}

      virtual = false
      {% if opts[:primary_key] %}
        @@primary_key = {{field_name.id.stringify}}
        PRIMARY_KEY = {{field_name.id.stringify}}
      {% elsif opts[:virtual] %}
        virtual = true
      {% end %}

      check_type!({{field_name}}, {{field_type}})
      @@changeset_fields << {{field_name}} unless virtual
      {% FIELDS << field_name %}

      property {{field_name.id}} : {{field_type}}?
    end

    # :nodoc:
    macro check_type!(field_name, field_type)
      {% unless VALID_FIELD_TYPES.includes?(field_type) %}
        raise Crecto::InvalidType.new("{{field_name}} type must be one of #{VALID_FIELD_TYPES.join(", ")}")
      {% end %}
    end

    # Setup extended methods
    macro setup
      extend BuildFromSQL

      # Builds a hash from all `FIELDS` defined
      def to_query_hash
        h = {} of Symbol => Int32 | Int64 | String | Float64 | Bool | Time | Nil
        {% for field in FIELDS %}
          h[{{field}}] = self.{{field.id}} if self.{{field.id}} && @@changeset_fields.includes?({{field}})
        {% end %}
        h
      end

      # Returns the value of the primary key field
      def pkey_value
        self.{{PRIMARY_KEY.id}}
      end

      # Return the primary key field as a String
      def self.primary_key
        @@primary_key
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