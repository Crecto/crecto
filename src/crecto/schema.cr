module Crecto
  module Schema
    include Crecto::Schema::HasMany
    include Crecto::Schema::HasOne
    include Crecto::Schema::BelongsTo

    VALID_FIELD_TYPES = [String, Int32, Float64, Bool, Time]
    VALID_FIELD_OPTIONS = [:primary_key, :virtual]

    property id : Int32?
    property created_at : Time?
    property updated_at : Time?
    property initial_values : Hash(Symbol, Int32 | Int64 | String | Float64 | Bool | Nil)?

    macro schema(table_name, &block)
      FIELDS = [] of String
      PRIMARY_KEY = "id"
      
      @@table_name = {{table_name.id.stringify}}
      @@primary_key = "id"
      @@changeset_fields = [] of Symbol
      @@initial_values = {} of Symbol => Int32 | Int64 | String | Float64 | Bool | Nil

      {{yield}}

      setup
    end

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

    macro check_type!(field_name, field_type)
      {% unless VALID_FIELD_TYPES.includes?(field_type) %}
        raise Crecto::InvalidType.new("{{field_name}} type must be one of #{VALID_FIELD_TYPES.join(", ")}")
      {% end %}
    end

    macro setup
      extend BuildFromSQL

      def to_query_hash
        h = {} of Symbol => Int32 | Int64 | String | Float64 | Bool | Nil
        {% for field in FIELDS %}
          h[{{field}}] = self.{{field.id}} if self.{{field.id}}
        {% end %}
        h
      end

      def pkey_value
        self.{{PRIMARY_KEY.id}}
      end

      def self.primary_key
        @@primary_key
      end

      def self.changeset_fields
        @@changeset_fields
      end

      def self.table_name
        @@table_name
      end
    end
  end
end