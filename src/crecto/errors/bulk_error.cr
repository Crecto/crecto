require "./crecto_error"

module Crecto
  # Error raised when bulk operations fail
  class BulkError < CrectoError
    getter operation_type : Symbol
    getter table_name : String
    getter failed_count : Int32
    getter success_count : Int32
    getter errors : Array(String)
    getter changeset_errors : Array(Hash(Symbol, Array(String)))

    def initialize(@operation_type : Symbol, @table_name : String, @failed_count : Int32, @success_count : Int32, @errors : Array(String) = [] of String, @changeset_errors : Array(Hash(Symbol, Array(String))) = [] of Hash(Symbol, Array(String)))
      super("Bulk #{operation_type} operation on #{table_name} failed: #{failed_count} of #{failed_count + success_count} operations failed")
    end
  end
end