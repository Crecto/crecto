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

      def self.execute(operation : Symbol, queryable, query : Crecto::Repo::Query, query_hash : Hash)
        connection = Db.checkout()

        result = case operation
        when :udpate_al
          update(connection, queryable, query, query_hash)
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
      def self.execute_on_instance(operation, changeset)
        connection = DB.checkout()

        result = case operation
        when :insert
          insert(connection, changeset)
        when :update
          update(connection, changeset)
        when :delete
          delete(connection, changeset)
        end

        DB.checkin(connection)
        result
      end

      private def self.get(connection, queryable, id)
        q =     ["SELECT *"]
        q.push  "FROM #{queryable.table_name}"
        q.push  "WHERE #{queryable.primary_key_field}=$1"
        q.push  "LIMIT 1"

        connection.exec(q.join(" "), [id])
      end

      private def self.all(connection, queryable, query)
        params = [] of DbValue | Array(DbValue)

        q =     ["SELECT"]
        q.push  query.selects.join(", ")
        q.push  "FROM #{queryable.table_name}"
        q.push  wheres(queryable, query, params) if query.wheres.any?
        q.push  or_wheres(queryable, query, params) if query.or_wheres.any?
        # TODO: JOINS
        q.push  order_bys(query) if query.order_bys.any?
        q.push  limit(query) unless query.limit.nil?
        q.push  offset(query) unless query.offset.nil?

        connection.exec(position_args(q.join(" ")), params)
      end

      private def self.insert(connection, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q =     ["INSERT INTO"]
        q.push  "#{changeset.instance.class.table_name}"
        q.push  "(#{fields_values[:fields]})"
        q.push  "VALUES"
        q.push  "(#{(1..fields_values[:values].size).map{ "?" }.join(", ")})"
        q.push  "RETURNING *"

        connection.exec(position_args(q.join(" ")), fields_values[:values])
      end

      private def self.update(connection, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q =     ["UPDATE"]
        q.push  "#{changeset.instance.class.table_name}"
        q.push  "SET"
        q.push  "(#{fields_values[:fields]})"
        q.push  "="
        q.push  "(#{(1..fields_values[:values].size).map{ "?" }.join(", ")})"
        q.push  "WHERE"
        q.push  "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"
        q.push  "RETURNING *"

        connection.exec(position_args(q.join(" ")), fields_values[:values])
      end

      private def self.update(connection, queryable, query, query_hash)
        fields_values = instance_fields_and_values(query_hash)
        params = [] of DbValue | Array(DbValue)

        q =     ["UPDATE"]
        q.push  "#{changeset.instance.class.table_name}"
        q.push  "SET"
        q.push  "(#{fields_values[:fields]})"
        q.push  "="
        q.push  "(#{(1..fields_values[:values].size).map{ "?" }.join(", ")})"
        q.push  wheres(queryable, query, params)

        connection.exec(position_args(q.join(" ")), fields_values[:values] + params)
      end

      private def self.delete(connection, changeset)
        q =     ["DELETE FROM"]
        q.push  "#{changeset.instance.class.table_name}"
        q.push  "WHERE"
        q.push  "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"
        q.push  "RETURNING *"

        connection.exec(q.join(" "))
      end

      private def self.wheres(queryable, query, params)
        q = ["WHERE "]
        where_clauses = [] of String

        query.wheres.each do |where|
          if where.is_a?(NamedTuple)
            where_clauses.push(add_where(where, params))
          elsif where.is_a?(Hash)
            where_clauses += add_where(where, queryable, params)
          end
        end
        
        q.push where_clauses.join(" AND ")
        q.join("")
      end

      private def self.or_wheres(queryable, query, params)
        q = ["WHERE "]
        where_clauses = [] of String

        query.or_wheres.each do |where|
          where_clauses += add_where(where.as(Hash), queryable, params)
        end
        
        q.push where_clauses.join(" OR")
        q.join("")
      end

      private def self.add_where(where : NamedTuple, params)
        where[:params].each{|param| params.push(param) }
        where[:clause]
      end

      private def self.add_where(where : Hash, queryable, params)
        where.keys.map do |key|
          [where[key]].flatten.each{|param| params.push(param) }

          resp = " #{queryable.table_name}.#{key}"
          resp += if where[key].is_a?(Array)
            " IN (" + where[key].as(Array).map{|p| "?" }.join(", ") + ")"
          else
            "=?"
          end
        end
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

      private def self.instance_fields_and_values(query_hash : Hash)
        {fields: query_hash.keys.join(", "), values: query_hash.values}
      end

      private def self.instance_fields_and_values(queryable_instance)
        instance_fields_and_values(queryable_instance.to_query_hash)
      end

      private def self.position_args(query_string : String)
        query = ""
        chunks = query_string.split("?")
        chunks.each_with_index do |chunk, i|
          query += chunk
          query += "$#{i + 1}" unless i == chunks.size - 1
        end
        query
      end

    end
  end
end