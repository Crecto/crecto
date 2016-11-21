require "pg"
require "pool/connection"

module Crecto
  module Adapters
    module Postgres
      ENV["DB_POOL_CAPACITY"] ||= "25"
      ENV["DB_POOL_TIMEOUT"] ||= "0.01"

      DB = ConnectionPool.new(ENV["DB_POOL_CAPACITY"].to_i, ENV["DB_POOL_TIMEOUT"].to_f) do
        PG.connect(ENV["PG_URL"])
      end

      def self.execute(operation : Symbol, queryable, query : Crecto::Repo::Query)
        connection = DB.checkout()

        result = case operation
        when :all
          all(connection, queryable, query)
        end

        DB.checkin(connection)
        result
      end

      def self.execute(operation : Symbol, queryable, id : Int32 | Int64 | String)
        connection = DB.checkout()

        result = case operation
        when :get
          get(connection, queryable, id)
        end

        DB.checkin(connection)
        result
      end

      def self.execute_on_instance(operation, queryable_instance)
        connection = DB.checkout()

        result = case operation
        when :insert
          insert(connection, queryable_instance)
        when :update
          update(connection, queryable_instance)
        when :delete
          delete(connection, queryable_instance)
        end

        DB.checkin(connection)
        result
      end

      private def self.get(connection, queryable, id)
        query_string = ["SELECT *"]
        query_string.push "FROM #{queryable.table_name}"
        query_string.push "WHERE #{queryable.primary_key}=#{id}"
        query_string.push "LIMIT 1"

        query = connection.exec(query_string.join(" "))
        query.rows[0]
      end

      private def self.all(connection, queryable, query)
        query_string = ["SELECT"]
        query_string.push query.selects.join(", ")
        query_string.push "FROM #{queryable.table_name}"
        query_string.push wheres(queryable, query) unless query.wheres.nil?
        # TODO: JOINS
        query_string.push order_bys(query) unless query.order_by.nil?
        query_string.push limit(query) unless query.limit.nil?
        query_string.push offset(query) unless query.offset.nil?
        query = connection.exec(query_string.join(" "))
        query.rows
      end

      private def self.insert(connection, queryable_instance)
        fields_values = instance_fields_and_values(queryable_instance)

        query_string = ["INSERT INTO"]
        query_string.push "#{queryable_instance.class.table_name}"
        query_string.push "(#{fields_values[:fields]})"
        query_string.push "VALUES"
        query_string.push "(#{fields_values[:values]})"
        query_string.push "RETURNING *"

        query = connection.exec(query_string.join(" "))
        queryable_instance.id = query.to_hash[0]["id"].as(Int32 | Int64)
        queryable_instance
      end

      private def self.update(connection, queryable_instance)
        fields_values = instance_fields_and_values(queryable_instance)

        query_string = ["UPDATE"]
        query_string.push "#{queryable_instance.class.table_name}"
        query_string.push "SET"
        query_string.push "(#{fields_values[:fields]})"
        query_string.push "="
        query_string.push "(#{fields_values[:values]})"
        query_string.push "WHERE"
        query_string.push "#{queryable_instance.class.primary_key}=#{queryable_instance.pkey_value}"
        query_string.push "RETURNING *"

        query = connection.exec(query_string.join(" "))
        query.rows[0]
      end

      private def self.instance_fields_and_values(queryable_instance)
        query_hash = queryable_instance.to_query_hash
        values = query_hash.values.map do |value|
          value.class == String ? "'#{value}'" : "#{value}"
        end
        {fields: query_hash.keys.join(", "), values: values.join(", ")}
      end

      private def self.delete(connection, queryable_instance)
        query_string = ["DELETE FROM"]
        query_string.push "#{queryable_instance.class.table_name}"
        query_string.push "WHERE"
        query_string.push "#{queryable_instance.class.primary_key}=#{queryable_instance.pkey_value}"
        query_string.push "RETURNING *"

        query = connection.exec(query_string.join(" "))
        query.rows[0]
      end

      private def self.wheres(queryable, query)
        query_string = ["WHERE "]

        wheres = query.wheres.as(Hash)
        where_clauses = wheres.keys.map do |key|
          resp = " #{queryable.table_name}.#{key}"
          if wheres[key].is_a?(String)
            resp += "='#{wheres[key]}'"
          elsif wheres[key].is_a?(Int32) || wheres[key].is_a?(Int64)
            resp += "=#{wheres[key]}"
          else
            resp += " in #{wheres[key]}"
          end
        end
        query_string.push where_clauses.join(" AND ")
        query_string.join("")
      end

      private def self.order_bys(query)
        order = query.order_by.as(String)
        "ORDER BY #{order}"
      end

      private def self.limit(query)
        "LIMIT #{query.limit}"
      end

      private def self.offset(query)
        "OFFSET #{query.offset}"
      end

    end
  end
end