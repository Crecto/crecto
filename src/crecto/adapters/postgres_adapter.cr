require "pg"
require "pool/connection"

module Crecto
  module Adapters

    #
    # Adapter module for PostgresSQL
    #
    # Uses [crystal-pg](https://github.com/will/crystal-pg) for now.
    #
    # Other adapters should follow this same pattern
    module Postgres
      ENV["DB_POOL_CAPACITY"] ||= "25"
      ENV["DB_POOL_TIMEOUT"] ||= "0.01"

      DB = ConnectionPool.new(ENV["DB_POOL_CAPACITY"].to_i, ENV["DB_POOL_TIMEOUT"].to_f) do
        PG.connect(ENV["PG_URL"])
      end

      #
      # Query data store using a *query*
      #
      def self.execute(operation : Symbol, queryable, query : Crecto::Repo::Query)
        connection = DB.checkout()

        result = case operation
        when :all
          all(connection, queryable, query)
        end

        DB.checkin(connection)
        result
      end

      #
      # Query data store using an *id*, returning a single record.
      #
      def self.execute(operation : Symbol, queryable, id : Int32 | Int64 | String)
        connection = DB.checkout()

        result = case operation
        when :get
          get(connection, queryable, id)
        end

        DB.checkin(connection)
        result
      end

      # Query data store in relation to a *queryable_instance* of Schema
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
        q =     ["SELECT *"]
        q.push  "FROM #{queryable.table_name}"
        q.push  "WHERE #{queryable.primary_key_field}=#{id}"
        q.push  "LIMIT 1"

        query = connection.exec(q.join(" "))
        queryable.from_sql(query.to_hash[0])
      end

      private def self.all(connection, queryable, query)
        q =     ["SELECT"]
        q.push  query.selects.join(", ")
        q.push  "FROM #{queryable.table_name}"
        q.push  wheres(queryable, query) if query.wheres.any?
        # TODO: JOINS
        q.push  order_bys(query) if query.order_bys.any?
        q.push  limit(query) unless query.limit.nil?
        q.push  offset(query) unless query.offset.nil?

        query = connection.exec(q.join(" "))
        query.to_hash.map{|row| queryable.from_sql(row) }
      end

      private def self.insert(connection, queryable_instance)
        queryable_instance.updated_at_to_now
        queryable_instance.created_at_to_now
        fields_values = instance_fields_and_values(queryable_instance)

        q =     ["INSERT INTO"]
        q.push  "#{queryable_instance.class.table_name}"
        q.push  "(#{fields_values[:fields]})"
        q.push  "VALUES"
        q.push  "(#{fields_values[:values]})"
        q.push  "RETURNING *"

        query = connection.exec(q.join(" "))
        queryable_instance.update_primary_key(query.to_hash[0]["id"].as(Int32))
        queryable_instance
      end

      private def self.update(connection, queryable_instance)
        queryable_instance.updated_at_to_now
        fields_values = instance_fields_and_values(queryable_instance)

        q =     ["UPDATE"]
        q.push  "#{queryable_instance.class.table_name}"
        q.push  "SET"
        q.push  "(#{fields_values[:fields]})"
        q.push  "="
        q.push  "(#{fields_values[:values]})"
        q.push  "WHERE"
        q.push  "#{queryable_instance.class.primary_key_field}=#{queryable_instance.pkey_value}"
        q.push  "RETURNING *"

        query = connection.exec(q.join(" "))
        query.to_hash[0]
      end

      private def self.delete(connection, queryable_instance)
        q =     ["DELETE FROM"]
        q.push  "#{queryable_instance.class.table_name}"
        q.push  "WHERE"
        q.push  "#{queryable_instance.class.primary_key_field}=#{queryable_instance.pkey_value}"
        q.push  "RETURNING *"

        query = connection.exec(q.join(" "))
        query.to_hash[0]
      end

      private def self.wheres(queryable, query)
        q = ["WHERE "]
        where_clauses = [] of String

        query.wheres.each do |where|
          if where.is_a?(String)
            where_clauses.push where
          elsif where.is_a?(Hash)
            where_clauses += where.keys.map do |key|
            resp = " #{queryable.table_name}.#{key}"
            if where[key].nil?
                resp += "= NULL"
            elsif where[key].is_a?(String)
              resp += "= '#{where[key]}'"
            elsif where[key].is_a?(Int32) || where[key].is_a?(Int64)
              resp += "= #{where[key]}"
            else
              resp += " in #{where[key]}"
            end
          end
          end
        end
        
        q.push where_clauses.join(" AND ")
        q.join("")
      end

      private def self.order_bys(query)
        "ORDER BY #{query.order_bys.join(", ")}"
      end

      private def self.limit(query)
        "LIMIT #{query.limit}"
      end

      private def self.offset(query)
        "OFFSET #{query.offset}"
      end

      private def self.instance_fields_and_values(queryable_instance)
        query_hash = queryable_instance.to_query_hash
        values = query_hash.values.map do |value|
          if value.nil?
            "NULL"
          elsif value.is_a?(String)
            "'#{value}'"
          elsif value.is_a?(Time)
            "'#{value.to_utc.to_s("%Y-%m-%d %H:%M:%S")}'"
          else
            "#{value}"
          end
        end
        {fields: query_hash.keys.join(", "), values: values.join(", ")}
      end

    end
  end
end