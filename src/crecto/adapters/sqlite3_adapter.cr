module Crecto
  module Adapters
    #
    # Adapter module for SQLite3
    #
    module SQLite3
      extend BaseAdapter

      def self.exec_execute(conn, query_string, params : Array)
        start = Time.now
        results = if conn.is_a?(DB::Database)
                    conn.exec(query_string, params)
                  else
                    conn.connection.exec(query_string, params)
                  end
        DbLogger.log(query_string, Time.new - start, params)
        results
      end

      def self.exec_execute(conn, query_string)
        start = Time.now
        results = if conn.is_a?(DB::Database)
                    conn.exec(query_string)
                  else
                    conn.connection.exec(query_string)
                  end
        DbLogger.log(query_string, Time.new - start)
        results
      end

      private def self.get(conn, queryable, id)
        q = ["SELECT *"]
        q.push "FROM #{queryable.table_name}"
        q.push "WHERE #{queryable.primary_key_field}=?"
        q.push "LIMIT 1"

        execute(conn, q.join(" "), [id])
      end

      private def self.insert(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = ["INSERT INTO"]
        q.push "#{changeset.instance.class.table_name}"
        q.push "(#{fields_values[:fields].join(", ")})"
        q.push "VALUES"
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"

        res = exec_execute(conn, q.join(" "), fields_values[:values])
        if changeset.instance.class.use_primary_key?
          last_insert_id = changeset.instance.pkey_value.nil? ? res.last_insert_id : changeset.instance.pkey_value.not_nil!
          execute(conn, "SELECT * FROM #{changeset.instance.class.table_name} WHERE #{changeset.instance.class.primary_key_field} = '#{last_insert_id}'")
        end
      end

      private def self.update_begin(table_name, fields_values)
        q = ["UPDATE"]
        q.push "#{table_name}"
        q.push "SET"
        q.push fields_values[:fields].map { |field_value| "#{field_value}=?" }.join(", ")
        q
      end

      private def self.update(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = update_begin(changeset.instance.class.table_name, fields_values)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=?"

        exec_execute(conn, q.join(" "), fields_values[:values] + [changeset.instance.pkey_value])
        execute(conn, "SELECT * FROM #{changeset.instance.class.table_name} WHERE #{changeset.instance.class.primary_key_field}=?", [changeset.instance.pkey_value])
      end

      private def self.delete(conn, changeset)
        q = delete_begin(changeset.instance.class.table_name)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=?"

        if conn.is_a?(DB::TopLevelTransaction)
          exec_execute(conn, q.join(" "), [changeset.instance.pkey_value])
        else
          sel = execute(conn, "SELECT * FROM #{changeset.instance.class.table_name} WHERE #{changeset.instance.class.primary_key_field}=?", [changeset.instance.pkey_value])
          exec_execute(conn, q.join(" "), [changeset.instance.pkey_value])
          sel
        end
      end

      private def self.delete(conn, queryable, query)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        exec_execute(conn, q.join(" "), params)
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
