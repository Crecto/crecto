module Crecto
  #
  # Changeset allows validating data, and tracking changes.
  #
  module Changeset(T)

    # :nodoc:
    REQUIRED_FIELDS = {} of String => Array(Symbol)
    # :nodoc:
    REQUIRED_FORMATS = {} of String => Array(NamedTuple(field: Symbol, pattern: Regex))
    # :nodoc:
    REQUIRED_ARRAY_INCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)))
    # :nodoc:
    REQUIRED_RANGE_INCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time) | Range(Time, Time)))
    # :nodoc:
    REQUIRED_ARRAY_EXCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)))
    # :nodoc:
    REQUIRED_RANGE_EXCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time) | Range(Time, Time)))
    # :nodoc:
    REQUIRED_LENGTHS = {} of String => Array(NamedTuple(field: Symbol, is: Int32 | Nil, min: Int32 | Nil, max: Int32 | Nil))

    def changeset(instance)
      Changeset(T).new(instance)
    end

    # Validate that a *field* is present.
    def validate_required(field : Symbol)
      REQUIRED_FIELDS[self.to_s] = [] of Symbol unless REQUIRED_FIELDS.has_key?(self.to_s)
      REQUIRED_FIELDS[self.to_s].push(field)
    end

    # Validates that an array of *fields* is present.
    def validate_required(fields : Array(Symbol))
      fields.each{|f| validate_required(f) }
    end

    # Validate the format for the value of *field* using a *pattern*
    def validate_format(field : Symbol, pattern : Regex)
      REQUIRED_FORMATS[self.to_s] = [] of NamedTuple(field: Symbol, pattern: Regex) unless REQUIRED_FORMATS.has_key?(self.to_s)
      REQUIRED_FORMATS[self.to_s].push({field: field, pattern: pattern})
    end

    # Validate the format for an array of *fields* values using a *pattern*
    def validate_format(fields : Array(Symbol), pattern : Regex)
      fields.each {|field| validate_format(field, pattern) }
    end

    # Validate the inclusion of *field* value is in *in*
    def validate_inclusion(field : Symbol, in : Array)
      REQUIRED_ARRAY_INCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)) unless REQUIRED_ARRAY_INCLUSIONS.has_key?(self.to_s)
      REQUIRED_ARRAY_INCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *field* value is in *in*
    def validate_inclusion(field : Symbol, in : Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time))
      REQUIRED_RANGE_INCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time)) unless REQUIRED_RANGE_INCLUSIONS.has_key?(self.to_s)
      REQUIRED_RANGE_INCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *fields* values is in *in*
    def validate_inclusion(fields : Array(Symbol), in : Array | Range)
      fields.each{|field| validate_inclusion(field, in) }
    end

    # Validate the inclusion of *field* value is not in *in*
    def validate_exclusion(field : Symbol, in : Array)
      REQUIRED_ARRAY_EXCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)) unless REQUIRED_ARRAY_EXCLUSIONS.has_key?(self.to_s)
      REQUIRED_ARRAY_EXCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *field* value is not in *in*
    def validate_exclusion(field : Symbol, in : Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time))
      REQUIRED_RANGE_EXCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time)) unless REQUIRED_RANGE_EXCLUSIONS.has_key?(self.to_s)
      REQUIRED_RANGE_EXCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *fields* values is not *in*
    def validate_exclusion(field : Array(Symbol), in : Array | Range)
      fields.each{|field| validate_exclusion(field, in) }
    end

    # Validate the length of *field* value using the following opts:
    #
    # * is: Int32
    # * min: Int32
    # * max: Int32
    #
    def validate_length(field : Symbol, **opts)
      opts = opts.to_h
      REQUIRED_LENGTHS[self.to_s] = [] of NamedTuple(field: Symbol, is: Int32 | Nil, min: Int32 | Nil, max: Int32 | Nil) unless REQUIRED_LENGTHS.has_key?(self.to_s)
      REQUIRED_LENGTHS[self.to_s].push({field: field, is: opts.fetch(:is, nil), min: opts.fetch(:min, nil), max: opts.fetch(:max, nil)})
    end

    # TODO: not done
    def validate_number
    end

    # TODO: not done
    def validate_confirmation
    end

    # TODO: not done
    def validate_acceptance
    end

    # TODO: not done
    def unique_constraint
    end
  end
end