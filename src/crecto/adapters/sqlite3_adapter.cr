module Crecto
  module Adapters
    #
    # Adapter module for SQLite3
    #
    module SQLite3
      extend BaseAdapter

      def self.exec_execute(conn, query_string, params : Array)
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
        values = query_hash.values.map { |x| x.is_a?(JSON::Any) ? x.to_json : x.as(DbValue) }
        {fields: query_hash.keys, values: values}
      end

      private def self.position_args(query_string : String)
        query_string
      end
    end
  end
end
