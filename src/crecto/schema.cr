module Crecto
  module Schema
    VALID_FIELD_TYPES = [:integer, :string, :float, :boolean]
    VALID_FIELD_OPTIONS = [:primary_key, :virtual]
    VALID_HAS_OPTIONS = [:foreign_key]
    VALID_BELONGS_TO_OPTIONS = [:foreign_key]

    macro schema(table_name, &block)
      @@table_name = {{table_name.id.stringify}}
      @@primary_key : String?
      @@changeset_fields = [] of String

      {{yield}}

      setup
    end

    macro field(field_name, field_type, *opts)
      virtual = false
      {% for opt in opts %}
        {% if opt[:primary_key] %}
          @@primary_key = {{field_name.id.stringify}}
        {% elsif opt[:virtual] %}
          virtual = true
        {% end %}
      {% end %}

      @@changeset_fields << {{field_name.id.stringify}} unless virtual
      check_type!(field_name, {{field_type}})

      {% field_type = "Int32 | Int64" if field_type == :integer %}
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