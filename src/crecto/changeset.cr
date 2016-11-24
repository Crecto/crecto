module Crecto
  module Changeset
    REQUIRED_FIELDS = [] of Symbol
    REQUIRED_FORMATS = [] of NamedTuple(field: Symbol, pattern: Regex)
    REQUIRED_INCLUSIONS = [] of NamedTuple(field: Symbol, in: Array(Int32 | Int64 | String | Bool | Float64 | Time))

    def changeset(instance)
      Changeset.new(instance)
    end

    def validate_required(field : Symbol)
      REQUIRED_FIELDS.push(field)
    end

    def validate_required(field : Array(Symbol))
      field.each{|f| validate_required(f) }
    end

    def validate_format(field : Symbol, pattern : Regex)
      REQUIRED_FORMATS.push({field: field, pattern: pattern})
    end

    def validate_format(fields : Array(Symbol), pattern : Regex)
      fields.each {|field| validate_format(field, pattern) }
    end

    def validate_inclusion(field : Symbol, in : Array | Enumerable)
      REQUIRED_INCLUSIONS.push({field: field, in: in})
    end

    def validate_inclusion(fields : Array(Symbol), in : Array | Enumerable)
      fields.each{|field| validate_inclusion(field, in) }
    end

    def validate_exclusion
    end

    def validate_length
    end

    def validate_number
    end

    def validate_confirmation
    end

    def validate_acceptance
    end

    def unique_constraint
    end
  end
end