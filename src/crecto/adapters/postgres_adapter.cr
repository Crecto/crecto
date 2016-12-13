require "pg"

module Crecto
  module Adapters

    #
    # Adapter module for PostgresSQL
    #
    # Uses [crystal-pg](https://github.com/will/crystal-pg) for now.
    #
    # Other adapters should follow this same pattern
    module Postgres
      ENV["CRECTO_MAX_POOL_SIZE"] ||= "25"
      ENV["CRECTO_INITIAL_POOL_SIZE"] ||= "1"
      ENV["CRECTO_POOL_TIMEOUT"] ||= "5.0"

      POOL = DB::Pool.new(
        max_pool_size: ENV["CRECTO_MAX_POOL_SIZE"].to_i,
        initial_pool_size: ENV["CRECTO_INITIAL_POOL_SIZE"].to_i,
        checkout_timeout: ENV["CRECTO_POOL_TIMEOUT"].to_f) do
        DB.open(ENV["PG_URL"])
      end

      #
      # Query data store using a *query*
      #
      def self.run(operation : Symbol, queryable, query : Crecto::Repo::Query)
        case operation
        when :all
          all(queryable, query)
        when :delete_all
          delete(queryable, query)
        end
      end

      def self.run(operation : Symbol, queryable, query : Crecto::Repo::Query, query_hash : Hash)
        case operation
        when :update_all
          update(queryable, query, query_hash)
        end
      end

      #
      # Query data store using an *id*, returning a single record.
      #
      def self.run(operation : Symbol, queryable, id : Int32 | Int64 | String | Nil)
        case operation
        when :get
          get(queryable, id)
        end
      end

      # 
      # Query data store using *sql*, returning multiple rows
      #
      def self.run(operation : Symbol, sql : String, params : Array(DbValue))
        case operation
        when :sql
          execute(position_args(sql), params)
        end
      end

      # Query data store in relation to a *queryable_instance* of Schema
      def self.run_on_instance(operation, changeset)
        case operation
        when :insert
          insert(changeset)
        when :update
          update(changeset)
        when :delete
          delete(changeset)
        end
      end

      def self.execute(query_string, params)
        connection = POOL.checkout
        result = connection.query(query_string, params)
        POOL.release connection
        result
      end

      def self.execute(query_string)
        connection = POOL.checkout
        result = connection.query(query_string)
        POOL.release connection
        result
      end

      private def self.get(queryable, id)
        q =     ["SELECT *"]
        q.push  "FROM #{queryable.table_name}"
        q.push  "WHERE #{queryable.primary_key_field}=$1"
        q.push  "LIMIT 1"

        execute(q.join(" "), [id])
      end

      private def self.all(queryable, query)
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

        execute(position_args(q.join(" ")), params)
      end

      private def self.insert(changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q =     ["INSERT INTO"]
        q.push  "#{changeset.instance.class.table_name}"
        q.push  "(#{fields_values[:fields]})"
        q.push  "VALUES"
        q.push  "(#{(1..fields_values[:values].size).map{ "?" }.join(", ")})"
        q.push  "RETURNING *"

        execute(position_args(q.join(" ")), fields_values[:values])
      end

      private def self.update_begin(table_name, fields_values)
        q =     ["UPDATE"]
        q.push  "#{table_name}"
        q.push  "SET"
        q.push  "(#{fields_values[:fields]})"
        q.push  "="
        q.push  "(#{(1..fields_values[:values].size).map{ "?" }.join(", ")})"
      end

      private def self.update(changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = update_begin(changeset.instance.class.table_name, fields_values)
        q.push  "WHERE"
        q.push  "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"
        q.push  "RETURNING *"

        execute(position_args(q.join(" ")), fields_values[:values])
      end

      private def self.update(queryable, query, query_hash)
        fields_values = instance_fields_and_values(query_hash)
        params = [] of DbValue | Array(DbValue)

        q = update_begin(queryable.table_name, fields_values)
        q.push  wheres(queryable, query, params) if query.wheres.any?
        q.push  or_wheres(queryable, query, params) if query.or_wheres.any?

        execute(position_args(q.join(" ")), fields_values[:values] + params)
      end

      private def self.delete_begin(table_name)
        q =     ["DELETE FROM"]
        q.push  "#{table_name}"
      end

      private def self.delete(changeset)
        q = delete_begin(changeset.instance.class.table_name)
        q.push  "WHERE"
        q.push  "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"
        q.push  "RETURNING *"

        execute(q.join(" "))
      end

      private def self.delete(queryable, query)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        execute(position_args(q.join(" ")), params)
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
