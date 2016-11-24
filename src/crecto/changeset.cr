module Crecto
  module Changeset
    include Validations

    REQUIRED_FIELDS = {} of String => Array(Symbol)
    REQUIRED_FORMATS = {} of String => Array(NamedTuple(field: Symbol, pattern: Regex))
    REQUIRED_INCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time) | Range(Int32, Int32)))
    REQUIRED_EXCLUSIONS = {} of String => Array(NamedTuple(field: Symbol, in: Array(String) | Array(Int32 | Int64 | String | Bool | Float64 | Time) | Range(Int32, Int32)))
    REQUIRED_LENGTHS = {} of String => Array(NamedTuple(field: Symbol, is: Int32 | Nil, min: Int32 | Nil, max: Int32 | Nil))

    def changeset(instance)
      Changeset.new(instance)
    end
  end
end