require "./crecto_error"

module Crecto
  # Error raised when association operations fail
  class AssociationError < CrectoError
    getter association_name : Symbol
    getter model_class : String
    getter operation : Symbol
    getter foreign_key : Symbol?

    def initialize(@association_name : Symbol, @model_class : String, @operation : Symbol, @foreign_key : Symbol? = nil)
      message = "Association '#{association_name}' on #{model_class} failed during #{operation}"
      message += " (foreign key: #{foreign_key})" if foreign_key
      super(message)
    end
  end
end