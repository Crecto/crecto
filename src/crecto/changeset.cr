module Crecto
  #
  # Changeset allows validating data, and tracking changes.
  #
  module Changeset(T)
    # :nodoc:
    private alias RangeTypes = Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time)
    # :nodoc:
    private alias ArrayOfAny = Array(String) | Array(Int32) | Array(Int64) | Array(Time) | Array(Int32 | Int64 | String | Bool | Float64 | Time)

    # :nodoc:
    REQUIRED_FIELDS = {} of String => Array(String)
    # :nodoc:
    REQUIRED_FORMATS = {} of String => Array({field: String, pattern: Regex})
    # :nodoc:
    REQUIRED_ARRAY_INCLUSIONS = {} of String => Array({field: String, in: ArrayOfAny})
    # :nodoc:
    REQUIRED_RANGE_INCLUSIONS = {} of String => Array({field: String, in: RangeTypes})
    # :nodoc:
    REQUIRED_ARRAY_EXCLUSIONS = {} of String => Array({field: String, in: ArrayOfAny})
    # :nodoc:
    REQUIRED_RANGE_EXCLUSIONS = {} of String => Array({field: String, in: RangeTypes})
    # :nodoc:
    REQUIRED_LENGTHS = {} of String => Array({field: String, is: Int32 | Nil, min: Int32 | Nil, max: Int32 | Nil})
    # :nodoc:
    UNIQUE_FIELDS = {} of String => Array(String)

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
    def validate_required(field : String | Symbol)
      REQUIRED_FIELDS[self.to_s] = [] of String unless REQUIRED_FIELDS.has_key?(self.to_s)
      REQUIRED_FIELDS[self.to_s].push(field.to_s)
    end

    # Validates that an array of *fields* is present.
    def validate_required(fields : Array(String | Symbol))
      fields.each { |f| validate_required(f) }
    end

    # Validate the format for the value of *field* using a *pattern*
    def validate_format(field : String | Symbol, pattern : Regex)
      REQUIRED_FORMATS[self.to_s] = [] of {field: String, pattern: Regex} unless REQUIRED_FORMATS.has_key?(self.to_s)
      REQUIRED_FORMATS[self.to_s].push({field: field.to_s, pattern: pattern})
    end

    # Validate the format for an array of *fields* values using a *pattern*
    def validate_format(fields : Array(String | Symbol), pattern : Regex)
      fields.each { |field| validate_format(field, pattern) }
    end

    def validate_inclusion(field : String | Symbol, args : Hash(String, (ArrayOfAny | RangeTypes)))
      raise "Missing :in argument" unless args.has_key?("in")
      validate_inclusion(field, args[:in])
    end

    def validate_inclusion(fields : Array(String | Symbol), args : Hash(String, (ArrayOfAny | RangeTypes)))
      raise "Missing :in argument" unless args.has_key?("in")
      validate_inclusion(fields, args[:in])
    end

    # Validate the inclusion of *field* value is in *inside*
    def validate_inclusion(field : String | Symbol, inside : Array)
      REQUIRED_ARRAY_INCLUSIONS[self.to_s] = [] of {field: String, in: ArrayOfAny} unless REQUIRED_ARRAY_INCLUSIONS.has_key?(self.to_s)
      REQUIRED_ARRAY_INCLUSIONS[self.to_s].push({field: field.to_s, in: inside})
    end

    # Validate the inclusion of *field* value is in *inside*
    def validate_inclusion(field : String | Symbol, inside : RangeTypes)
      REQUIRED_RANGE_INCLUSIONS[self.to_s] = [] of {field: String, in: RangeTypes} unless REQUIRED_RANGE_INCLUSIONS.has_key?(self.to_s)
      REQUIRED_RANGE_INCLUSIONS[self.to_s].push({field: field.to_s, in: inside})
    end

    # Validate the inclusion of *fields* values is in *inside*
    def validate_inclusion(fields : Array(String | Symbol), inside : Array | Range)
      fields.each { |field| validate_inclusion(field.to_s, inside) }
    end

    def validate_exclusion(field : String | Symbol, args : Hash(String, (ArrayOfAny | RangeTypes)))
      raise "Missing :in argument" unless args.has_key?("in")
      validate_exclusion(field, args[:in])
    end

    def validate_exclusion(fields : Array(String | Symbol), args : Hash(String, (ArrayOfAny | RangeTypes)))
      raise "Missing :in argument" unless args.has_key?("in")
      validate_exclusion(fields, args[:in])
    end

    # Validate the inclusion of *field* value is not in *inside*
    def validate_exclusion(field : String | Symbol, inside : Array)
      REQUIRED_ARRAY_EXCLUSIONS[self.to_s] = [] of {field: String, in: ArrayOfAny} unless REQUIRED_ARRAY_EXCLUSIONS.has_key?(self.to_s)
      REQUIRED_ARRAY_EXCLUSIONS[self.to_s].push({field: field.to_s, in: inside})
    end

    # Validate the inclusion of *field* value is not in *inside*
    def validate_exclusion(field : String | Symbol, inside : RangeTypes)
      REQUIRED_RANGE_EXCLUSIONS[self.to_s] = [] of {field: Symbol, in: RangeTypes} unless REQUIRED_RANGE_EXCLUSIONS.has_key?(self.to_s)
      REQUIRED_RANGE_EXCLUSIONS[self.to_s].push({field: field.to_s, in: inside})
    end

    # Validate the inclusion of *fields* values is not *inside*
    def validate_exclusion(fields : Array(String | Symbol), inside : Array | Range)
      fields.each { |field| validate_exclusion(field, inside) }
    end

    # Validate the length of *field* value using the following opts:
    #
    # * is: Int32
    # * min: Int32
    # * max: Int32
    #
    def validate_length(field : String | Symbol, **opts)
      REQUIRED_LENGTHS[self.to_s] = [] of {field: String, is: Int32?, min: Int32?, max: Int32?} unless REQUIRED_LENGTHS.has_key?(self.to_s)
      REQUIRED_LENGTHS[self.to_s].push({field: field.to_s, is: opts[:is]?, min: opts[:min]?, max: opts[:max]?})
    end

    # Validate the length of *fields* value using the following opts:
    #
    # * is: Int32
    # * min: Int32
    # * max: Int32
    #
    def validate_length(fields : Array(String | Symbol), **opts)
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

    # Catches unique constraint database errors for *field* and converts them to changeset errors
    def unique_constraint(field : String | Symbol)
      UNIQUE_FIELDS[self.to_s] = [] of String unless UNIQUE_FIELDS.has_key?(self.to_s)
      UNIQUE_FIELDS[self.to_s].push(field.to_s)
    end

    # Catches unique constraint database errors for all *fields* and converts them to changeset errors
    def unique_constraint(fields : Array(String | Symbol))
      fields.each { |f| unique_constraint(f) }
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
        validate_inclusion(field, opts.to_h)
      end

      if opts = constrains[:exclusion]?
        validate_exclusion(field, opts.to_h)
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
