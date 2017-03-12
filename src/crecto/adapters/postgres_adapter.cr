module Crecto
  module Adapters
    #
    # Adapter module for PostgresSQL
    #
    # Uses [crystal-pg](https://github.com/will/crystal-pg) for now.
    #
    # Other adapters should follow this same pattern
    module Postgres
      @@ENV_KEY = "PG_URL"
      extend BaseAdapter

      def self.run(operation : Symbol, queryable, query : Crecto::Repo::Query, tx : DB::Transaction?)
        case operation
        when :delete_all
          exec_delete(queryable, query, tx)
        end
      end

      def self.execute(query_string, params, tx : DB::Transaction?)
        return execute(query_string, params) if tx.nil?
        tx.connection.query(query_string, params)
      end

      def self.execute(query_string, tx : DB::Transaction?)
        return execute(query_string) if tx.nil?
        get_db().query(query_string)
      end

      def self.exec_execute(query_string, params, tx : DB::Transaction?)
        return execute(query_string, params) if tx.nil?
        tx.connection.exec(query_string, params)
      end

      def self.exec_execute(query_string, tx : DB::Transaction?)
        return execute(query_string) if tx.nil?
        tx.connection.exec(query_string)
      end

      private def self.get(queryable, id)
        q = ["SELECT *"]
        q.push "FROM #{queryable.table_name}"
        q.push "WHERE #{queryable.primary_key_field}=$1"
        q.push "LIMIT 1"

        execute(q.join(" "), [id])
      end

      private def self.insert(changeset, tx : DB::Transaction?)
        fields_values = instance_fields_and_values(changeset.instance)

        q = ["INSERT INTO"]
        q.push "#{changeset.instance.class.table_name}"
        q.push "(#{fields_values[:fields]})"
        q.push "VALUES"
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"
        q.push "RETURNING *"

        execute(position_args(q.join(" ")), fields_values[:values], tx)
      end

      private def self.update_begin(table_name, fields_values)
        q = ["UPDATE"]
        q.push "#{table_name}"
        q.push "SET"
        q.push "(#{fields_values[:fields]})"
        q.push "="
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"
      end

      private def self.update(changeset, tx)
        fields_values = instance_fields_and_values(changeset.instance)

        q = update_begin(changeset.instance.class.table_name, fields_values)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"
        q.push "RETURNING *"

        execute(position_args(q.join(" ")), fields_values[:values], tx)
      end

      private def self.delete(changeset, tx : DB::Transaction?)
        q = delete_begin(changeset.instance.class.table_name)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"
        q.push "RETURNING *" if tx.nil?

        exec_execute(q.join(" "), tx)
      end

      private def self.delete(queryable, query : Crecto::Repo::Query, tx : DB::Transaction?)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        execute(position_args(q.join(" ")), params, tx)
      end

      private def self.exec_delete(queryable, query : Crecto::Repo::Query, tx : DB::Transaction)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        exec_execute(position_args(q.join(" ")), params, tx)
      end

      private def self.instance_fields_and_values(query_hash : Hash)
        values = query_hash.values.map{|x| x.is_a?(JSON::Any) ? x.to_json : x.as(DbValue)}
        {fields: query_hash.keys.join(", "), values: values}
      end
    end
  end
end
