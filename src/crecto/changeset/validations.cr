module Crecto
  module Changeset
    module Validations
      def validate_required(field : Symbol)
        REQUIRED_FIELDS[self.to_s] = [] of Symbol unless REQUIRED_FIELDS.has_key?(self.to_s)
        REQUIRED_FIELDS[self.to_s].push(field)
      end

      def validate_required(field : Array(Symbol))
        field.each{|f| validate_required(f) }
      end

      def validate_format(field : Symbol, pattern : Regex)
        REQUIRED_FORMATS[self.to_s] = [] of NamedTuple(field: Symbol, pattern: Regex) unless REQUIRED_FORMATS.has_key?(self.to_s)
        REQUIRED_FORMATS[self.to_s].push({field: field, pattern: pattern})
      end

      def validate_format(fields : Array(Symbol), pattern : Regex)
        fields.each {|field| validate_format(field, pattern) }
      end

      def validate_inclusion(field : Symbol, in : Array)
        REQUIRED_ARRAY_INCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)) unless REQUIRED_ARRAY_INCLUSIONS.has_key?(self.to_s)
        REQUIRED_ARRAY_INCLUSIONS[self.to_s].push({field: field, in: in})
      end

      def validate_inclusion(field : Symbol, in : Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time))
        REQUIRED_RANGE_INCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time)) unless REQUIRED_RANGE_INCLUSIONS.has_key?(self.to_s)
        REQUIRED_RANGE_INCLUSIONS[self.to_s].push({field: field, in: in})
      end

      def validate_inclusion(fields : Array(Symbol), in : Array | Range)
        fields.each{|field| validate_inclusion(field, in) }
      end

      def validate_exclusion(field : Symbol, in : Array)
        REQUIRED_ARRAY_EXCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)) unless REQUIRED_ARRAY_EXCLUSIONS.has_key?(self.to_s)
        REQUIRED_ARRAY_EXCLUSIONS[self.to_s].push({field: field, in: in})
      end

      def validate_exclusion(field : Symbol, in : Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time))
        REQUIRED_RANGE_EXCLUSIONS[self.to_s] = [] of NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time)) unless REQUIRED_RANGE_EXCLUSIONS.has_key?(self.to_s)
        REQUIRED_RANGE_EXCLUSIONS[self.to_s].push({field: field, in: in})
      end

      def validate_exclusion(field : Array(Symbol), in : Array | Range)
        fields.each{|field| validate_exclusion(field, in) }
      end

      def validate_length(field : Symbol, **opts)
        opts = opts.to_h
        REQUIRED_LENGTHS[self.to_s] = [] of NamedTuple(field: Symbol, is: Int32 | Nil, min: Int32 | Nil, max: Int32 | Nil) unless REQUIRED_LENGTHS.has_key?(self.to_s)
        REQUIRED_LENGTHS[self.to_s].push({field: field, is: opts.fetch(:is, nil), min: opts.fetch(:min, nil), max: opts.fetch(:max, nil)})
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
end