module Crecto
  module Adapters
    #
    # Adapter module for SQLite3
    #
    module SQLite3
      extend BaseAdapter

      def self.exec_execute(conn, query_string, params : Array)
        start = Time.local
        # Add SQL capture for tests
        Crecto::Adapters.sqls << query_string
        results = if conn.is_a?(DB::Database)
                    conn.exec(query_string, args: params)
                  else
                    conn.connection.exec(query_string, args: params)
                  end
        DbLogger.log(query_string, Time.local - start, params)
        results
      end

      def self.exec_execute(conn, query_string)
        start = Time.local
        # Add SQL capture for tests
        Crecto::Adapters.sqls << query_string
        results = if conn.is_a?(DB::Database)
                    conn.exec(query_string)
                  else
                    conn.connection.exec(query_string)
                  end
        DbLogger.log(query_string, Time.local - start)
        results
      end

      private def self.get(conn, queryable, id)
        q = String.build do |builder|
          builder <<
            "SELECT * FROM " << queryable.table_name <<
            " WHERE (" << queryable.primary_key_field << "=?)" <<
            " LIMIT 1"
        end

        execute(conn, q, [id])
      end

      private def self.insert(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = String.build do |builder|
          builder << "INSERT INTO " << changeset.instance.class.table_name
          builder << " ("
          fields_values[:fields].each do |field|
            builder << field << ", "
          end

          builder.back(2)
          builder << ") VALUES ("
          fields_values[:values].size.times do
            builder << "?, "
          end
          builder.back(2)
          builder << ')'
        end

        res = exec_execute(conn, q, fields_values[:values])
        if changeset.instance.class.use_primary_key?
          last_insert_id = changeset.instance.pkey_value.nil? ? res.last_insert_id : changeset.instance.pkey_value.not_nil!
          execute(conn, "SELECT * FROM #{changeset.instance.class.table_name} WHERE (#{changeset.instance.class.primary_key_field} = '#{last_insert_id}')")
        else
          res
        end
      end

      private def self.update_begin(builder, table_name, fields_values)
        builder << "UPDATE " << table_name << " SET "
        fields_values[:fields].each do |field_value|
          builder << field_value << "=?, "
        end

        builder.back(2)
      end

      private def self.update(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = String.build do |builder|
          update_begin(builder, changeset.instance.class.table_name, fields_values)
          builder << " WHERE (" << changeset.instance.class.primary_key_field << "=?)"
        end

        exec_execute(conn, q, fields_values[:values] + [changeset.instance.pkey_value])
        execute(conn, "SELECT * FROM #{changeset.instance.class.table_name} WHERE (#{changeset.instance.class.primary_key_field}=?)", [changeset.instance.pkey_value])
      end

      private def self.delete(conn, changeset)
        q = String.build do |builder|
          delete_begin(builder, changeset.instance.class.table_name)
          builder << " WHERE (" << changeset.instance.class.primary_key_field << "=?)"
        end

        if conn.is_a?(DB::TopLevelTransaction)
          exec_execute(conn, q, [changeset.instance.pkey_value])
        else
          sel = execute(conn, "SELECT * FROM #{changeset.instance.class.table_name} WHERE (#{changeset.instance.class.primary_key_field}=?)", [changeset.instance.pkey_value])
          exec_execute(conn, q, [changeset.instance.pkey_value])
          sel
        end
      end

      private def self.delete(conn, queryable, query)
        params = [] of DbValue | Array(DbValue)

        q = String.build do |builder|
          delete_begin(builder, queryable.table_name)
          where_expression(builder, queryable, query, params)
        end

        exec_execute(conn, q, params)
      end

      private def self.instance_fields_and_values(query_hash : Hash)
        values = query_hash.values.map do |x|
          if x.is_a?(JSON::Any)
            x.to_json
          elsif x.is_a?(Time)
            # SQLite3 stores Time as ISO8601 string for consistency
            Crecto::Adapters::BaseAdapter.format_time_for_db(x)
          else
            x.as(DbValue)
          end
        end
        {fields: query_hash.keys, values: values}
      end

      private def self.position_args(query_string : String)
        query_string
      end

      # SQLite3 bulk insert implementation using transaction-wrapped individual inserts
      # SQLite3 doesn't support multi-row VALUES efficiently, so we use individual inserts in a transaction
      def self.run_bulk_insert(conn : DB::Database | DB::Transaction, queryable, changesets : Array(Crecto::Changeset::Changeset), result : Crecto::BulkResult, invalid_indices : Array(Int32) = [] of Int32)
        return if changesets.empty?

        # Set timestamps for all records
        changesets.each do |changeset|
          changeset.instance.updated_at_to_now
          changeset.instance.created_at_to_now
        end

        begin
          # For SQLite3, the most efficient approach is individual inserts within a transaction
          # If we're already in a transaction, use it directly
          if conn.is_a?(DB::Transaction)
            # Use existing transaction
            changesets.each_with_index do |changeset, index|
              # Skip invalid changesets
              next if invalid_indices.includes?(index)

              begin
                individual_result = self.insert(conn, changeset)

                # Extract the ID from the insert result
                if individual_result.is_a?(DB::ResultSet)
                  begin
                    individual_result.each do
                      inserted_id = individual_result.read(PkeyValue)
                      result.add_success(inserted_id)
                    end
                  ensure
                    individual_result.close
                  end
                elsif changeset.instance.pkey_value
                  result.add_success(changeset.instance.pkey_value)
                end

              rescue individual_ex : Exception
                result.add_error(index, individual_ex, changeset.instance.to_query_hash.transform_keys(&.to_s))
              end
            end
          else
            # Create a new transaction for atomic bulk insert
            conn.transaction do |tx|
              changesets.each_with_index do |changeset, index|
                # Skip invalid changesets
                next if invalid_indices.includes?(index)

                begin
                  individual_result = self.insert(tx, changeset)

                  # Extract the ID from the insert result
                  if individual_result.is_a?(DB::ResultSet)
                    begin
                      individual_result.each do
                        inserted_id = individual_result.read(PkeyValue)
                        result.add_success(inserted_id)
                      end
                    ensure
                      individual_result.close
                    end
                  elsif changeset.instance.pkey_value
                    result.add_success(changeset.instance.pkey_value)
                  end

                rescue individual_ex : Exception
                  result.add_error(index, individual_ex, changeset.instance.to_query_hash.transform_keys(&.to_s))
                end
              end
            end
          end

        rescue ex : Exception
          # Handle transaction failure
          DbLogger.log_error("SQLITE3_BULK_INSERT_ERROR", "SQLite3 bulk insert transaction failed", {
            "queryable" => queryable.to_s,
            "record_count" => changesets.size.to_s,
            "error_class" => ex.class.name,
            "error_message" => ex.message || "Unknown error"
          })

          # Mark any remaining unprocessed records as failed
          changesets.each_with_index do |changeset, index|
            if result.errors.none? { |error| error.index == index } && result.inserted_ids.size <= index
              result.add_error(index, ex, changeset.instance.to_query_hash.transform_keys(&.to_s))
            end
          end
        end
      end
    end
  end
end
