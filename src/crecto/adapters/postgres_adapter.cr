module Crecto
  module Adapters
    #
    # Adapter module for PostgresSQL
    #
    module Postgres
      extend BaseAdapter

      def self.exec_execute(conn, query_string, params)
        return execute(conn, query_string, params) if conn.is_a?(DB::Database)
        conn.connection.exec(query_string, params)
      end

      def self.exec_execute(conn, query_string)
        return execute(conn, query_string) if conn.is_a?(DB::Database)
        conn.connection.exec(query_string)
      end

      private def self.get(conn, queryable, id)
        q = ["SELECT *"]
        q.push "FROM #{queryable.table_name}"
        q.push "WHERE #{queryable.primary_key_field}=$1"
        q.push "LIMIT 1"

        execute(conn, q.join(" "), [id])
      end

      private def self.insert(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = ["INSERT INTO"]
        q.push "#{changeset.instance.class.table_name}"
        q.push "(#{fields_values[:fields]})"
        q.push "VALUES"
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"
        q.push "RETURNING *"

        execute(conn, position_args(q.join(" ")), fields_values[:values])
      end

      private def self.update_begin(table_name, fields_values)
        q = ["UPDATE"]
        q.push "#{table_name}"
        q.push "SET"
        q.push "(#{fields_values[:fields]})"
        q.push "="
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"
      end

      private def self.update(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = update_begin(changeset.instance.class.table_name, fields_values)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"
        q.push "RETURNING *"

        execute(conn, position_args(q.join(" ")), fields_values[:values])
      end

      private def self.exec_delete(conn, queryable, query : Crecto::Repo::Query)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        exec_execute(conn, position_args(q.join(" ")), params)
      end

      private def self.instance_fields_and_values(query_hash : Hash)
        values = query_hash.values.map { |x| x.is_a?(JSON::Any) ? x.to_json : x.as(DbValue) }
        {fields: query_hash.keys.join(", "), values: values}
      end
    end
  end
end
