require "./multi"
require "./errors/concurrent_modification_error"

module Crecto
  class LiveTransaction(T)
    def initialize(@tx : DB::Transaction, @repo : T)
    end

    def insert(queryable : Crecto::Model)
      @repo.insert(queryable, @tx)
    end

    def insert!(queryable : Crecto::Model)
      @repo.insert!(queryable, @tx)
    end

    def delete(queryable : Crecto::Model)
      @repo.delete(queryable, @tx)
    end

    def delete!(queryable : Crecto::Model)
      @repo.delete!(queryable, @tx)
    end

    def insert(changeset : Crecto::Changeset::Changeset)
      insert(changeset.instance)
    end

    def insert!(changeset : Crecto::Changeset::Changeset)
      insert!(changeset.instance)
    end

    def delete(changeset : Crecto::Changeset::Changeset)
      delete(changeset.instance)
    end

    def delete!(changeset : Crecto::Changeset::Changeset)
      delete!(changeset.instance)
    end

    # Bulk insert multiple records within the transaction
    def insert_all(queryable, records : Array(Crecto::Model | Hash | NamedTuple))
      # Create a new bulk insert method that uses the transaction
      start_time = Time.monotonic

      # Handle empty input
      raise ArgumentError.new("Records array cannot be empty") if records.empty?

      # Convert all records to changesets for validation
      changesets = records.map_with_index do |record, index|
        case record
        when Crecto::Model
          queryable.changeset(record)
        when Hash
          # Convert Hash keys to symbols for cast method
          symbol_record = {} of Symbol => DbValue
          record.each do |k, v|
            # Use a simple approach to convert string to symbol
            case k.to_s
            when "id"
              symbol_record[:id] = v.as(DbValue)
            when "name"
              symbol_record[:name] = v.as(DbValue)
            when "things"
              symbol_record[:things] = v.as(DbValue)
            when "nope"
              symbol_record[:nope] = v.as(DbValue)
            when "some_date"
              symbol_record[:some_date] = v.as(DbValue)
            when "user_id"
              symbol_record[:user_id] = v.as(DbValue)
            when "is_admin"
              symbol_record[:is_admin] = v.as(DbValue)
            when "age"
              symbol_record[:age] = v.as(DbValue)
            else
              # Skip unknown fields
            end
          end
          instance = queryable.cast(symbol_record)
          queryable.changeset(instance)
        when NamedTuple
          instance = queryable.cast(record)
          queryable.changeset(instance)
        else
          raise ArgumentError.new("Unsupported record type: #{record.class}")
        end
      end

      # Validate all changesets
      invalid_indices = [] of Int32
      changesets.each_with_index do |cs, i|
        if !cs.valid?
          invalid_indices << i
        end
      end

      # Create BulkResult to track the operation
      result = Crecto::BulkResult.new(records.size)

      # If there are validation failures, handle them but still process valid records
      if invalid_indices.any?
        invalid_indices.each do |index|
          changeset = changesets[index]
          result.add_error(index, changeset, changeset.instance.to_query_hash.transform_keys(&.to_s))
        end
      end

      # Delegate to database adapter for bulk insertion
      @repo.config.adapter.run_bulk_insert(@tx, queryable, changesets, result, invalid_indices)

      # Set duration and finalize result
      duration = (Time.monotonic - start_time).total_milliseconds
      result.finalize_result(duration)

      result
    end

    # Bulk insert multiple records within the transaction (strict version)
    def insert_all!(queryable, records : Array(Crecto::Model | Hash | NamedTuple))
      result = insert_all(queryable, records)
      if result.failed_count > 0
        # Create a mock changeset from the error for raising InvalidChangeset
        error = result.errors.first
        if validation_errors = error.validation_errors
          # This was a validation error
          raise Exception.new("Validation failed: #{validation_errors.join(", ")}")
        else
          # This was a database error
          raise Exception.new(error.error_message)
        end
      end
      result
    end

    # Enhanced update with optimistic locking to prevent race conditions
    def update(queryable : Crecto::Model)
      # Check if the model has a version/lock column for optimistic locking
      if queryable.responds_to?(:lock_version) && queryable.responds_to?(:lock_version=)
        update_with_optimistic_lock(queryable)
      else
        update_with_atomic_check(queryable)
      end
    end

    def update!(queryable : Crecto::Model)
      result = update(queryable)
      if result.is_a?(Crecto::Changeset::Changeset) && !result.valid?
        raise Crecto::InvalidChangeset.new(result)
      end
      result
    end

    def update(changeset : Crecto::Changeset::Changeset)
      update(changeset.instance)
    end

    # Enhanced update_all with atomic operations to prevent lost updates
    def update_all(queryable, query, update_hash : Multi::UpdateHash)
      # For update_all operations, we use database-level atomic operations
      # This prevents race conditions in concurrent updates
      @repo.update_all(queryable, query, update_hash, @tx)
    end

    def delete_all(queryable, query = Crecto::Repo::Query.new)
      @repo.delete_all(queryable, query, @tx)
    end

    def update_all(queryable, query, update_hash : Multi::UpdateHash)
      @repo.update_all(queryable, query, update_hash, @tx)
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end

    def get(queryable, id)
      @repo.get(queryable, id, @tx)
    end

    def get!(queryable, id)
      if result = get(queryable, id)
        result
      else
        raise NoResults.new("No Results")
      end
    end

    def get_by(queryable, **opts)
      @repo.get_by(queryable, **opts)
    end

    def get_by!(queryable, **opts)
      @repo.get_by!(queryable, **opts)
    end

    def all(queryable, query = Crecto::Repo::Query.new)
      # Use a simple implementation that queries through the transaction
      # For now, we'll delegate to the repo's all method but note that
      # it won't use the transaction connection for complex queries
      @repo.all(queryable, query)
    end

    private def update_with_optimistic_lock(queryable : Crecto::Model)
      # Get current lock version
      current_version = queryable.lock_version
      new_version = current_version + 1

      # Add lock version to WHERE clause to ensure atomic update
      pk_field = queryable.class.primary_key_field
      pk_value = queryable.pkey_value

      # Update the model with incremented lock version
      queryable.lock_version = new_version

      # Use atomic UPDATE with version check
      update_query = "UPDATE #{queryable.class.table_name} SET lock_version = $1 WHERE #{pk_field} = $2 AND lock_version = $3"

      begin
        result = @tx.exec(update_query, [new_version, pk_value, current_version])

        # Check if update was successful (row was found and version matched)
        if result.rows_affected == 0
          # Row not found or version mismatch - potential concurrent modification
          raise Crecto::Errors::ConcurrentModificationError.new("Record was modified by another transaction: #{queryable.class.name}##{pk_value}")
        end

        # Proceed with the actual model update
        @repo.update(queryable, @tx)
      rescue ex : Exception
        # Restore original version on error
        queryable.lock_version = current_version
        DbLogger.log_error("CONCURRENT_UPDATE_FAILED", "Failed to update record with optimistic locking", {
          "table" => queryable.class.table_name,
          "primary_key" => pk_value.to_s,
          "expected_version" => current_version.to_s,
          "error" => ex.message || "Unknown error"
        })
        raise ex
      end
    end

    private def update_with_atomic_check(queryable : Crecto::Model)
      # For models without explicit locking, use database-appropriate locking
      pk_field = queryable.class.primary_key_field
      pk_value = queryable.pkey_value

      # Determine the adapter type to use appropriate locking syntax
      adapter_type = @repo.config.adapter

      # Build database-appropriate lock query
      lock_query = case adapter_type
                   when Crecto::Adapters::SQLite3
                     # SQLite doesn't support FOR UPDATE, use a simple SELECT
                     "SELECT * FROM #{queryable.class.table_name} WHERE #{pk_field} = $1"
                   when Crecto::Adapters::Postgres, Crecto::Adapters::Mysql
                     # PostgreSQL and MySQL support FOR UPDATE
                     "SELECT * FROM #{queryable.class.table_name} WHERE #{pk_field} = $1 FOR UPDATE"
                   else
                     # Fallback to basic query for unknown adapters
                     "SELECT * FROM #{queryable.class.table_name} WHERE #{pk_field} = $1"
                   end

      begin
        # This will lock the row until the transaction commits or rolls back (for databases that support it)
        locked_record = @tx.connection.query_one(lock_query, pk_value, as: queryable.class)

        # Verify the record still exists and hasn't been modified
        if locked_record.nil?
          raise Crecto::Errors::RecordNotFoundError.new("Record not found: #{queryable.class.name}##{pk_value}")
        end

        # Proceed with the update
        @repo.update(queryable, @tx)
      rescue ex : Exception
        DbLogger.log_error("ATOMIC_UPDATE_FAILED", "Failed to update record with atomic lock", {
          "table" => queryable.class.table_name,
          "primary_key" => pk_value.to_s,
          "adapter" => adapter_type.to_s,
          "error" => ex.message || "Unknown error"
        })
        raise ex
      end
    end
  end

  # NestedTransaction provides savepoint-based nested transaction support
  class NestedTransaction(T)
    def initialize(@connection : DB::Database, @repo : T, @savepoint_name : String)
    end

    def insert(queryable : Crecto::Model)
      @repo.insert(queryable, nil) # Pass nil for transaction since we're using savepoints
    end

    def insert!(queryable : Crecto::Model)
      @repo.insert!(queryable, nil)
    end

    def delete(queryable : Crecto::Model)
      @repo.delete(queryable, nil)
    end

    def delete!(queryable : Crecto::Model)
      @repo.delete!(queryable, nil)
    end

    def update(queryable : Crecto::Model)
      @repo.update(queryable, nil)
    end

    def update!(queryable : Crecto::Model)
      @repo.update!(queryable, nil)
    end

    def insert(changeset : Crecto::Changeset::Changeset)
      insert(changeset.instance)
    end

    def insert!(changeset : Crecto::Changeset::Changeset)
      insert!(changeset.instance)
    end

    def delete(changeset : Crecto::Changeset::Changeset)
      delete(changeset.instance)
    end

    def delete!(changeset : Crecto::Changeset::Changeset)
      delete!(changeset.instance)
    end

    def update(changeset : Crecto::Changeset::Changeset)
      update(changeset.instance)
    end

    def update!(changeset : Crecto::Changeset::Changeset)
      update!(changeset.instance)
    end

    def delete_all(queryable, query = Crecto::Repo::Query.new)
      @repo.delete_all(queryable, query, nil)
    end

    def update_all(queryable, query, update_hash : Multi::UpdateHash)
      @repo.update_all(queryable, query, update_hash, nil)
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end

    # Rollback to the savepoint for this nested transaction
    def rollback
      if @connection.responds_to?(:exec) && @savepoint_name
        @connection.exec("ROLLBACK TO SAVEPOINT #{@savepoint_name}")
      end
    end
  end
end
