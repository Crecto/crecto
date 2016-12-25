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
    CREATED_AT_FIELD  = "created_at"
    UPDATED_AT_FIELD  = "updated_at"
    PRIMARY_KEY_FIELD = "id"
    ASSOCIATIONS      = Array(NamedTuple(association_type: Symbol,
    key: Symbol,
    this_klass: Model.class,
    klass: Model.class,
    foreign_key: Symbol,
    foreign_key_value: Proc(Model, PkeyValue),
    set_association: Proc(Model, Array(Model), Nil))).new

    # schema block macro
    macro schema(table_name, &block)
      include Crecto::Schema::HasMany
      include Crecto::Schema::HasOne
      include Crecto::Schema::BelongsTo

      # macro constants
      VALID_FIELD_TYPES = [String, Int64, Int32, Float32, Float64, Bool, Time, Int32 | Int64, Float32 | Float64]
      VALID_FIELD_OPTIONS = [:primary_key, :virtual]
      FIELDS = [] of NamedTuple(name: Symbol, type: String)

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
      {% virtual = false %}
      {% primary_key = false %}
      {% if opts[:primary_key] %}
        PRIMARY_KEY_FIELD = {{field_name.id.stringify}}
        {% primary_key = true %}
      {% elsif opts[:virtual] %}
        {% virtual = true %}
      {% end %}

      check_type!({{field_name}}, {{field_type}})

      # cache fields in class variable and macro variable
      {% unless virtual %}
        @@changeset_fields << {{field_name}}
      {% end %}

      {% FIELDS.push({name: field_name, type: field_type}) unless primary_key %}
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
      def initialize
      end

      {% mapping = FIELDS.map { |field| field[:name].id.stringify + ": {type: " + (field[:type] == "Int64" ? "DbBigInt" : field[:type].id.stringify) + ", nilable: true}" } %}
      {% mapping.push(PRIMARY_KEY_FIELD.id.stringify + ": {type: DbBigInt, nilable: true}") %}

      {% unless CREATED_AT_FIELD == nil %}
        {% mapping.push(CREATED_AT_FIELD.id.stringify + ": {type: Time, nilable: true}") %}
      {% end %}

      {% unless UPDATED_AT_FIELD == nil %}
        {% mapping.push(UPDATED_AT_FIELD.id.stringify + ": {type: Time, nilable: true}") %}
      {% end %}

      DB.mapping({ {{mapping.uniq.join(", ").id}} })

      # Builds a hash from all `FIELDS` defined
      def to_query_hash
        query_hash = {} of Symbol => DbValue

        {% for field in FIELDS %}
          if self.{{field[:name].id}} && @@changeset_fields.includes?({{field[:name]}})
            query_hash[{{field[:name]}}] = self.{{field[:name].id}}
            query_hash[{{field[:name]}}] = query_hash[{{field[:name]}}].as(Time).to_utc if query_hash[{{field[:name]}}].is_a?(Time)
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
        self.{{PRIMARY_KEY_FIELD.id}}.as(PkeyValue)
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

      # Get the Class for the assocation name
      # i.e. :posts => Post
      def self.klass_for_association(association : Symbol)
        ASSOCIATIONS.select{|a| a[:key] == association && a[:this_klass] == self}.first[:klass]
      end

      # Get the foreign key for the association
      # i.e. :posts => :user_id
      def self.foreign_key_for_association(association : Symbol) : Symbol
        ASSOCIATIONS.select{|a| a[:key] == association && a[:this_klass] == self}.first[:foreign_key]
      end

      # Get the foreign key value from the relation object
      # i.e. :posts, post => post.user_id
      def self.foreign_key_value_for_association(association : Symbol, item)
        ASSOCIATIONS.select{|a| a[:key] == association && a[:this_klass] == self}.first[:foreign_key_value].call(item)
      end

      # Set the value for the association
      # i.e. :posts, user, [posts] => user.posts = [posts]
      def self.set_value_for_association(association : Symbol, item, items)
        ASSOCIATIONS.select{|a| a[:key] == association && a[:this_klass] == self}.first[:set_association].call(item, items)
      end

      # Get the association type for the association
      # i.e. :posts => :has_many
      def self.association_type_for_association(association : Symbol)
        ASSOCIATIONS.select{|a| a[:key] == association && a[:this_klass] == self}.first[:association_type]
      end

    end
  end
end
