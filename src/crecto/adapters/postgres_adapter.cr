module Crecto
  module Adapters
    #
    # Adapter module for PostgresSQL
    #
    module Postgres
      extend BaseAdapter

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
          builder << " RETURNING *"
        end

        execute(conn, position_args(q), fields_values[:values] + [changeset.instance.pkey_value])
      end

      private def self.instance_fields_and_values(query_hash : Hash)
        values = query_hash.values.map do |x|
          if x.is_a?(JSON::Any)
            x.to_json
          elsif x.is_a?(Array)
            x = x.to_json
            x = x.sub(0, "{").sub(x.size - 1, "}")
            elsif x.is_a?(Time)
            # PostgreSQL handles Time natively with timezone awareness
            Crecto::Adapters::BaseAdapter.format_time_for_db(x)
          else
            x.as(DbValue)
          end
        end
        {fields: query_hash.keys, values: values}
      end

      # PostgreSQL bulk insert implementation using multi-row VALUES syntax
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

          builder << " RETURNING " << queryable.primary_key_field
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
          result_set = execute(conn, position_args(query), all_values)

          # Extract inserted IDs from the result set
          if result_set.is_a?(DB::ResultSet)
            begin
              result_set.each do
                inserted_id = result_set.read(PkeyValue)
                result.add_success(inserted_id)
              end
            ensure
              result_set.close
            end
          end

        rescue ex : Exception
          # Handle bulk insert failure
          DbLogger.log_error("POSTGRES_BULK_INSERT_ERROR", "PostgreSQL bulk insert failed", {
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
              if individual_result.is_a?(DB::ResultSet)
                begin
                  individual_result.each do
                    inserted_id = individual_result.read(PkeyValue)
                    result.add_success(inserted_id)
                  end
                ensure
                  individual_result.close
                end
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
