require "./crecto_error"

module Crecto
  module Errors
    # Raised when a concurrent modification is detected during optimistic locking
    class ConcurrentModificationError < CrectoError
      def initialize(message)
        super(message)
      end
    end

    # Raised when a record is not found during atomic operations
    class RecordNotFoundError < CrectoError
      def initialize(message)
        super(message)
      end
    end
  end
end