module Crecto
  module Schema
    VALID_FIELD_TYPES = [:integer, :string, :float, :boolean]
    VALID_FIELD_OPTIONS = [:primary_key, :virtual]
    VALID_HAS_OPTIONS = [:foreign_key]
    VALID_BELONGS_TO_OPTIONS = [:foreign_key]
    FIELDS = [] of String
    PRIMARY_KEY = "id"

    property id : (Int32 | Int64)?
    property created_at : Time?
    property updated_at : Time?

    macro schema(table_name, &block)
      @@table_name = {{table_name.id.stringify}}
      @@primary_key = "id"
      @@changeset_fields = [] of Symbol

      {{yield}}

      setup
    end

    macro field(field_name, field_type, **opts)
      virtual = false
      {% if opts[:primary_key] %}
        @@primary_key = {{field_name.id.stringify}}
        PRIMARY_KEY = {{field_name.id.stringify}}
      {% elsif opts[:virtual] %}
        virtual = true
      {% end %}

      @@changeset_fields << {{field_name}} unless virtual
      {% FIELDS << field_name %}
      check_type!(field_name, {{field_type}})

      {% field_type = "Int32 | Int64" if field_type == :integer %}
      {% field_type = "Int32 | Int64" if field_type == :text %}
      {% field_type = :float64 if field_type == :float %}
      {% field_type = :bool if field_type == :boolean %}

      property {{field_name.id}} : {{field_type.camelcase.id + "?"}}
    end

    macro has_many(name, queryable)

    end

    macro has_one(name, queryable)

    end

    macro belongs_to(name, queryable)

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