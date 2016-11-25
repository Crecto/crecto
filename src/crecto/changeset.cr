module Crecto
  module Changeset
    include Validations

    REQUIRED_FIELDS = {} of String => Array(Symbol)
    REQUIRED_FORMATS = {} of String => Array(NamedTuple(field: Symbol, pattern: Regex))
    REQUIRED_ARRAY_INCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)))
    REQUIRED_RANGE_INCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time) | Range(Time, Time)))
    REQUIRED_ARRAY_EXCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time)))
    REQUIRED_RANGE_EXCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Range(Int32, Int32) | Range(Float64, Float64) | Range(Time, Time) | Range(Time, Time)))
    REQUIRED_LENGTHS = {} of String => Array(NamedTuple(field: Symbol, is: Int32 | Nil, min: Int32 | Nil, max: Int32 | Nil))

    def changeset(instance)
      Changeset.new(instance)
    end
  end
end