require "./crecto_error"

module Crecto
  # Error raised when iterator operations fail
  class IteratorError < CrectoError
    getter query : String?
    getter batch_size : Int32
    getter processed_count : Int32
    getter original_error : Exception?

    def initialize(@query : String?, @batch_size : Int32, @processed_count : Int32, @original_error : Exception? = nil)
      message = "Iterator operation failed"
      message += " after processing #{processed_count} records" if processed_count > 0
      message += " with batch size #{batch_size}"
      message += " for query: #{query}" if query
      message += " - #{original_error.message}" if original_error

      super(message)
    end
  end
end