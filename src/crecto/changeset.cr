module Crecto
  #
  # Changeset allows validating data, and tracking changes.
  #
  module Changeset(T)
    # :nodoc:
    private alias RangeTypes = Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time)
    # :nodoc:
    private alias ArrayOfAny = Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)

    # :nodoc:
    REQUIRED_FIELDS = {} of String => Array(Symbol)
    # :nodoc:
    REQUIRED_FORMATS = {} of String => Array({field: Symbol, pattern: Regex})
    # :nodoc:
    REQUIRED_ARRAY_INCLUSIONS = {} of String => Array({field: Symbol, in: ArrayOfAny})
    # :nodoc:
    REQUIRED_RANGE_INCLUSIONS = {} of String => Array({field: Symbol, in: RangeTypes})
    # :nodoc:
    REQUIRED_ARRAY_EXCLUSIONS = {} of String => Array({field: Symbol, in: ArrayOfAny})
    # :nodoc:
    REQUIRED_RANGE_EXCLUSIONS = {} of String => Array({field: Symbol, in: RangeTypes})
    # :nodoc:
    REQUIRED_LENGTHS = {} of String => Array({field: Symbol, is: Int32 | Nil, min: Int32 | Nil, max: Int32 | Nil})

    macro extended
      # :nodoc:
      REQUIRED_GENERIC = [] of {message: String, validation: Proc({{@type.id}}, Bool?) | Proc({{@type.id}}, Bool)}

      # Validates generic block against an instance of the class
      def self.validate(message : String, block : {{@type.id}} -> _)
        REQUIRED_GENERIC.push({message: message, validation: block})
      end

      # :nodoc:
      def self.required_generics
        REQUIRED_GENERIC
      end
    end

    def changeset(instance)
      Changeset(T).new(instance.as(T))
    end

    # Validate that a *field* is present.
    def validate_required(field : Symbol)
      REQUIRED_FIELDS[self.to_s] = [] of Symbol unless REQUIRED_FIELDS.has_key?(self.to_s)
      REQUIRED_FIELDS[self.to_s].push(field)
    end

    # Validates that an array of *fields* is present.
    def validate_required(fields : Array(Symbol))
      fields.each { |f| validate_required(f) }
    end

    # Validate the format for the value of *field* using a *pattern*
    def validate_format(field : Symbol, pattern : Regex)
      REQUIRED_FORMATS[self.to_s] = [] of {field: Symbol, pattern: Regex} unless REQUIRED_FORMATS.has_key?(self.to_s)
      REQUIRED_FORMATS[self.to_s].push({field: field, pattern: pattern})
    end

    # Validate the format for an array of *fields* values using a *pattern*
    def validate_format(fields : Array(Symbol), pattern : Regex)
      fields.each { |field| validate_format(field, pattern) }
    end

    # Validate the inclusion of *field* value is in *in*
    def validate_inclusion(field : Symbol, in : Array)
      REQUIRED_ARRAY_INCLUSIONS[self.to_s] = [] of {field: Symbol, in: ArrayOfAny} unless REQUIRED_ARRAY_INCLUSIONS.has_key?(self.to_s)
      REQUIRED_ARRAY_INCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *field* value is in *in*
    def validate_inclusion(field : Symbol, in : RangeTypes)
      REQUIRED_RANGE_INCLUSIONS[self.to_s] = [] of {field: Symbol, in: RangeTypes} unless REQUIRED_RANGE_INCLUSIONS.has_key?(self.to_s)
      REQUIRED_RANGE_INCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *fields* values is in *in*
    def validate_inclusion(fields : Array(Symbol), in : Array | Range)
      fields.each { |field| validate_inclusion(field, in) }
    end

    # Validate the inclusion of *field* value is not in *in*
    def validate_exclusion(field : Symbol, in : Array)
      REQUIRED_ARRAY_EXCLUSIONS[self.to_s] = [] of {field: Symbol, in: ArrayOfAny} unless REQUIRED_ARRAY_EXCLUSIONS.has_key?(self.to_s)
      REQUIRED_ARRAY_EXCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *field* value is not in *in*
    def validate_exclusion(field : Symbol, in : RangeTypes)
      REQUIRED_RANGE_EXCLUSIONS[self.to_s] = [] of {field: Symbol, in: RangeTypes} unless REQUIRED_RANGE_EXCLUSIONS.has_key?(self.to_s)
      REQUIRED_RANGE_EXCLUSIONS[self.to_s].push({field: field, in: in})
    end

    # Validate the inclusion of *fields* values is not *in*
    def validate_exclusion(fields : Array(Symbol), in : Array | Range)
      fields.each { |field| validate_exclusion(field, in) }
    end

    # Validate the length of *field* value using the following opts:
    #
    # * is: Int32
    # * min: Int32
    # * max: Int32
    #
    def validate_length(field : Symbol, **opts)
      REQUIRED_LENGTHS[self.to_s] = [] of {field: Symbol, is: Int32?, min: Int32?, max: Int32?} unless REQUIRED_LENGTHS.has_key?(self.to_s)
      REQUIRED_LENGTHS[self.to_s].push({field: field, is: opts[:is]?, min: opts[:min]?, max: opts[:max]?})
    end

    # Validate the length of *field* value using the following opts:
    #
    # * is: Int32
    # * min: Int32
    # * max: Int32
    #
    def validate_length(fields : Array(Symbol), **opts)
      fields.each { |field| validate_length(field, **opts) }
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

    # TODO: not done - https://hexdocs.pm/ecto/Ecto.Changeset.html#unique_constraint/3
    def unique_constraint
    end

    # Assigns multiple validations for one or many *field*s.
    # *contrains* can include:
    #   * `presence: Bool`
    #   * `format: {pattern: Regex}`
    #   * `inclusion: {in: (Array | Range)}`
    #   * `exclusion: {in: (Array | Range)}`
    #   * `length: {is: Int32?, min: Int32?, max: Int32?}`
    #
    # ```
    # class User
    #   include Crecto::Schema
    #   extend Crecto::Changeset(User)
    #
    #   schema "users" do
    #     field :first_name, String
    #     field :last_name, String
    #     field :rank, Int32
    #   end
    #
    #   validates :first_name,
    #     length: {min: 3, max: 9}
    #
    #   validates [:first_name, :last_name],
    #     presence: true,
    #     format: {pattern: /^[a-zA-Z]+$/},
    #     exclusion: {in: ["foo", "bar"]}
    #
    #   validates :rank,
    #     inclusion: {in: 1..100}
    # end
    # ```
    def validates(field, **constrains)
      # return validate_required(field) if constrains.empty?
      validate_required(field) if constrains[:presence]?

      if opts = constrains[:format]?
        validate_format(field, **opts)
      end

      if opts = constrains[:inclusion]?
        validate_inclusion(field, **opts)
      end

      if opts = constrains[:exclusion]?
        validate_exclusion(field, **opts)
      end

      if opts = constrains[:length]?
        validate_length(field, **opts)
      end

      # TODO include in this method:
      #   validate_number
      #   validate_confirmation
      #   validate_acceptance
      #   unique_constraint
    end
  end
end
