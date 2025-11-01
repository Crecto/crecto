module Crecto
  # Result of a bulk insert operation
  #
  # ```
  # result = Repo.insert_all(User, users)
  # result.successful_count      # => 150
  # result.failed_count          # => 0
  # result.inserted_ids          # => [1, 2, 3, ...]
  # result.errors                # => [] of BulkError
  # result.duration_ms           # => 45.2
  # ```
  class BulkResult
    getter successful_count : Int32
    getter failed_count : Int32
    getter inserted_ids : Array(PkeyValue)
    getter errors : Array(BulkInsertError)
    getter duration_ms : Float64
    getter total_count : Int32

    def initialize(@total_count : Int32)
      @successful_count = 0
      @failed_count = 0
      @inserted_ids = [] of PkeyValue
      @errors = [] of BulkInsertError
      @duration_ms = 0.0
    end

    def successful?
      @failed_count == 0
    end

    def partial_success?
      @successful_count > 0 && @failed_count > 0
    end

    def complete_failure?
      @successful_count == 0 && @failed_count > 0
    end

    def success_rate
      return 0.0 if @total_count == 0
      (@successful_count.to_f64 / @total_count.to_f64 * 100).round(2)
    end

    # Update statistics after operation completion
    def finalize_result(@duration_ms : Float64)
      @failed_count = @total_count - @successful_count
    end

    # Add a successful insertion
    def add_success(inserted_id : PkeyValue)
      @successful_count += 1
      @inserted_ids << inserted_id
    end

    # Add a failed insertion
    def add_error(index : Int32, error : Exception, record_hash : Hash(String, DbValue | ArrayDbValue)? = nil)
      bulk_error = BulkInsertError.new(index, error, record_hash)
      @errors << bulk_error
    end

    # Add a failed insertion from a changeset
    def add_error(index : Int32, changeset : Crecto::Changeset::Changeset, record_hash : Hash(String, DbValue | ArrayDbValue)? = nil)
      bulk_error = BulkInsertError.new(index, changeset, record_hash)
      @errors << bulk_error
    end

    # Summary information
    def to_h
      {
        "total_count" => @total_count,
        "successful_count" => @successful_count,
        "failed_count" => @failed_count,
        "success_rate_percent" => success_rate,
        "duration_ms" => @duration_ms,
        "inserted_ids" => @inserted_ids,
        "error_count" => @errors.size,
        "errors" => @errors.map(&.to_h)
      }
    end

    # Human readable summary
    def to_s
      "BulkResult: #{@successful_count}/#{@total_count} successful (#{success_rate}%) in #{@duration_ms}ms"
    end
  end

  # Detailed error information for a failed bulk insert operation
  #
  # ```
  # error = result.errors.first
  # error.index                 # => 42 (zero-based index in original array)
  # error.error_message         # => "Invalid email format"
  # error.error_class           # => "ArgumentError"
  # error.record_hash           # => {"name" => "John", "email" => "invalid"}
  # error.database_error_code   # => "23514" (PostgreSQL constraint violation)
  # ```
  class BulkInsertError
    getter index : Int32
    getter error_message : String
    getter error_class : String
    getter record_hash : Hash(String, DbValue | ArrayDbValue)?
    getter database_error_code : String?
    getter timestamp : Time
    getter validation_errors : Array(String)?

    def initialize(@index : Int32, error : Exception, @record_hash : Hash(String, DbValue | ArrayDbValue)? = nil)
      @error_message = error.message || "Unknown error"
      @error_class = error.class.name
      @database_error_code = extract_database_error_code(error)
      @timestamp = Time.local
      @validation_errors = nil
    end

    def initialize(@index : Int32, changeset : Crecto::Changeset::Changeset, @record_hash : Hash(String, DbValue | ArrayDbValue)? = nil)
      @error_message = "Validation failed"
      @error_class = "ValidationError"
      @database_error_code = nil
      @timestamp = Time.local
      @validation_errors = changeset.errors.map(&.to_s)
    end

    # Extract database-specific error codes when available
    private def extract_database_error_code(error : Exception) : String?
      # PostgreSQL error codes in message format: "ERROR: 23514: check_violation"
      message = error.message.to_s

      # PostgreSQL error code pattern
      if match = message.match(/\b(0[0-9]{4}|[0-9]{5})\b/)
        return match[1]
      end

      # MySQL error codes in message format: "ERROR 1062 (23000): Duplicate entry"
      if match = message.match(/\b([0-9]{4})\b/)
        return match[1]
      end

      nil
    end

    # Check if this is a constraint violation
    def constraint_violation?
      case @database_error_code
      when "23505", "23514", "23000", "1062" then true
      else
        @error_message.includes?("constraint") ||
        @error_message.includes?("duplicate") ||
        @error_message.includes?("unique") ||
        @error_message.includes?("foreign key")
      end
    end

    # Check if this is a data type error
    def data_type_error?
      @error_message.includes?("invalid") ||
      @error_message.includes?("type") ||
      @error_message.includes?("format") ||
      @error_message.includes?("cast") ||
      @error_class.includes?("ArgumentError") ||
      @error_class.includes?("ValidationError")
    end

    # Check if this is a connection error
    def connection_error?
      @error_message.includes?("connection") ||
      @error_message.includes?("timeout") ||
      @error_message.includes?("pool") ||
      @error_class.includes?("ConnectionError")
    end

    # Check if this error might be recoverable
    def recoverable?
      connection_error? ||
      @error_message.includes?("lock") ||
      @error_message.includes?("deadlock")
    end

    # Detailed error information
    def to_h
      {
        "index" => @index,
        "error_message" => @error_message,
        "error_class" => @error_class,
        "database_error_code" => @database_error_code,
        "timestamp" => @timestamp.to_s,
        "validation_errors" => @validation_errors,
        "is_constraint_violation" => constraint_violation?,
        "is_data_type_error" => data_type_error?,
        "is_connection_error" => connection_error?,
        "is_recoverable" => recoverable?,
        "record_hash" => @record_hash
      }
    end

    # Human readable description
    def to_s
      "BulkError[#{@index}]: #{@error_class} - #{@error_message}"
    end
  end
end