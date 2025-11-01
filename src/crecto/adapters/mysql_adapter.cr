module Crecto
  module Adapters
    #
    # Adapter module for MySQL
    #
    module Mysql
      extend BaseAdapter

      def self.exec_execute(conn, query_string, params : Array)
        # Validate parameter count to prevent IndexError
        param_count = query_string.count('?')
        if param_count != params.size
          raise ArgumentError.new("Parameter count mismatch: expected #{param_count} parameters, got #{params.size}. Query: #{query_string}")
        end

        start = Time.local
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
          builder << "SELECT * FROM " << queryable.table_name
          builder << " WHERE (" << queryable.primary_key_field << "=?)"
          builder << " LIMIT 1"
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
          builder << fields_values[:values].size.times { builder << "?, " }
          builder.back(2)
          builder << ')'
        end

        query = exec_execute(conn, q, fields_values[:values])
        return query if conn.is_a?(DB::TopLevelTransaction)

        if changeset.instance.class.use_primary_key?
          last_insert_id = changeset.instance.pkey_value.nil? ? "LAST_INSERT_ID()" : "'#{changeset.instance.pkey_value.not_nil!}'"
          execute(conn, "SELECT * FROM #{changeset.instance.class.table_name} WHERE (#{changeset.instance.class.primary_key_field} = #{last_insert_id})")
        else
          query
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
        {fields: query_hash.keys, values: query_hash.values.map do |v|
          if v.is_a?(Time)
            # MySQL: Convert to UTC for consistent storage, format as DATETIME/TIMESTAMP
            Crecto::Adapters::BaseAdapter.format_time_for_db(v)
          else
            v.as(DbValue)
          end
        end}
      end

      private def self.position_args(query_string : String)
        query_string
      end

      # MySQL bulk insert implementation using multi-row VALUES syntax
      def self.run_bulk_insert(conn : DB::Database | DB::Transaction, queryable, changesets : Array(Crecto::Changeset::Changeset), result : Crecto::BulkResult, invalid_indices : Array(Int32) = [] of Int32)
        return if changesets.empty?

        # Set timestamps for all records
        changesets.each do |changeset|
          changeset.instance.updated_at_to_now
          changeset.instance.created_at_to_now
        end

        # Determine valid changesets by filtering out invalid indices
        valid_indices = changesets.each_index.select { |index| !invalid_indices.includes?(index) }

        return if valid_indices.empty?

        # Get field structure from first valid changeset
        first_changeset = changesets[valid_indices.first]
        first_fields_values = instance_fields_and_values(first_changeset.instance)
        all_fields = first_fields_values[:fields]

        # Ensure all records have the same field structure
        valid_indices.each do |index|
          changeset = changesets[index]
          fields_values = instance_fields_and_values(changeset.instance)
          if fields_values[:fields] != all_fields
            result.add_error(index, ArgumentError.new("Inconsistent field structure in bulk insert"), changeset.instance.to_query_hash.transform_keys(&.to_s))
            return
          end
        end

        # Build bulk INSERT query with multiple VALUES clauses
        query = String.build do |builder|
          builder << "INSERT INTO " << queryable.table_name
          builder << " (" << all_fields.map(&.to_s).join(", ") << ")"
          builder << " VALUES "

          valid_indices.each_with_index do |index, i|
            changeset = changesets[index]
            fields_values = instance_fields_and_values(changeset.instance)
            builder << "("
            fields_values[:values].size.times { builder << "?, " }
            builder.back(2)
            builder << ")"
            builder << ", " unless i == valid_indices.size - 1
          end
        end

        # Flatten all values for parameter binding using existing pattern
        all_values = [] of DbValue | Array(DbValue)
        valid_indices.each do |index|
          changeset = changesets[index]
          fields_values = instance_fields_and_values(changeset.instance)
          fields_values[:values].each { |value| all_values << value }
        end

        begin
          # Execute the bulk insert
          exec_execute(conn, query, all_values)

          # MySQL doesn't return inserted IDs directly, so we need to query them
          # Get the first inserted ID using LAST_INSERT_ID()
          if queryable.use_primary_key? && changesets[valid_indices.first].instance.pkey_value.nil?
            first_id_query = "SELECT LAST_INSERT_ID()"
            first_id_result = if conn.is_a?(DB::Database)
                              conn.scalar(first_id_query)
                            else
                              conn.connection.scalar(first_id_query)
                            end

            if first_id_result
              first_id = first_id_result.as(PkeyValue).as(Int64)

              # Generate sequential IDs for all inserted records
              valid_indices.each do
                result.add_success(first_id)
                first_id = first_id + 1
              end
            end
          else
            # If records have predefined primary keys, add them as successes
            valid_indices.each do |index|
              changeset = changesets[index]
              if primary_key = changeset.instance.pkey_value
                result.add_success(primary_key)
              end
            end
          end

        rescue ex : Exception
          # Handle bulk insert failure
          DbLogger.log_error("MYSQL_BULK_INSERT_ERROR", "MySQL bulk insert failed", {
            "queryable" => queryable.to_s,
            "record_count" => changesets.size.to_s,
            "error_class" => ex.class.name,
            "error_message" => ex.message || "Unknown error"
          })

          # Try individual inserts to identify failed records
          changesets.each_with_index do |changeset, index|
            begin
              # Try to insert record individually
              individual_result = self.insert(conn, changeset)

              # Extract the ID from the individual insert result
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
    end
  end
end
