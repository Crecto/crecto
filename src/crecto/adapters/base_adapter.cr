module Crecto
  module Adapters
    #
    # BaseAdapter module
    # Extended by actual adapters
    module BaseAdapter
      #
      # Query data store using a *query*
      #
      def run(conn : DB::Database | DB::Transaction, operation : Symbol, queryable, query : Crecto::Repo::Query)
        case operation
        when :all
          all(conn, queryable, query)
        when :delete_all
          delete(conn, queryable, query)
        end
      end

      def run(conn : DB::Database | DB::Transaction, operation : Symbol, queryable, query : Crecto::Repo::Query, query_hash : Hash)
        case operation
        when :update_all
          update(conn, queryable, query, query_hash)
        end
      end

      #
      # Query data store using an *id*, returning a single record.
      #
      def run(conn : DB::Database | DB::Transaction, operation : Symbol, queryable, id : Int32 | Int64 | String | Nil)
        case operation
        when :get
          get(conn, queryable, id)
        end
      end

      #
      # Query data store using *sql*, returning multiple rows
      #
      def run(conn : DB::Database | DB::Transaction, operation : Symbol, sql : String, params : Array(DbValue))
        case operation
        when :sql
          execute(conn, position_args(sql), params)
        end
      end

      # Query data store in relation to a *queryable_instance* of Schema
      def run_on_instance(conn : DB::Database | DB::Transaction, operation, changeset)
        case operation
        when :insert
          insert(conn, changeset)
        when :update
          update(conn, changeset)
        when :delete
          delete(conn, changeset)
        end
      end

      def execute(conn, query_string, params)
        start = Time.now
        results = if conn.is_a?(DB::Database)
                    conn.query(query_string, params)
                  else
                    conn.connection.query(query_string, params)
                  end
        DbLogger.log(query_string, Time.new - start, params)
        results
      end

      def execute(conn, query_string)
        start = Time.now
        results = if conn.is_a?(DB::Database)
                    conn.query(query_string)
                  else
                    conn.connection.query(query_string)
                  end
        DbLogger.log(query_string, Time.new - start)
        results
      end

      def exec_execute(conn, query_string, params)
        return execute(conn, query_string, params) if conn.is_a?(DB::Database)
        conn.connection.exec(query_string, params)
      end

      def exec_execute(conn, query_string)
        return execute(conn, query_string) if conn.is_a?(DB::Database)
        conn.connection.exec(query_string)
      end

      private def get(conn, queryable, id)
        q = ["SELECT *"]
        q.push "FROM #{queryable.table_name}"
        q.push "WHERE #{queryable.primary_key_field}=$1"
        q.push "LIMIT 1"

        execute(conn, q.join(" "), [id])
      end

      private def insert(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = ["INSERT INTO"]
        q.push "#{changeset.instance.class.table_name}"
        q.push "(#{fields_values[:fields]})"
        q.push "VALUES"
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"
        q.push "RETURNING *"

        execute(conn, position_args(q.join(" ")), fields_values[:values])
      end

      def aggregate(conn, queryable, ag, field)
        conn.scalar(build_aggregate_query(queryable, ag, field))
      end

      def aggregate(conn, queryable, ag, field, query : Crecto::Repo::Query)
        params = [] of DbValue | Array(DbValue)
        q = [build_aggregate_query(queryable, ag, field)]
        q.push joins(queryable, query, params) if query.joins.any?
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?
        q.push order_bys(query) if query.order_bys.any?
        q.push limit(query) unless query.limit.nil?
        q.push offset(query) unless query.offset.nil?

        start = Time.now
        query_string = position_args(q.join(" "))
        results = conn.scalar(query_string, params)
        DbLogger.log(query_string, Time.new - start, params)
        results
      end

      private def build_aggregate_query(queryable, ag, field)
        "SELECT #{ag}(#{queryable.table_name}.#{field}) from #{queryable.table_name}"
      end

      private def all(conn, queryable, query)
        params = [] of DbValue | Array(DbValue)

        q = ["SELECT"]

        if query.distincts.nil?
          q.push query.selects.map { |s| "#{queryable.table_name}.#{s}" }.join(", ")
        else
          q.push "DISTINCT #{query.distincts}"
        end
        q.push "FROM #{queryable.table_name}"
        q.push joins(queryable, query, params) if query.joins.any?
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?
        q.push order_bys(query) if query.order_bys.any?
        q.push limit(query) unless query.limit.nil?
        q.push offset(query) unless query.offset.nil?
        q.push "GROUP BY #{query.group_bys}" if !query.group_bys.nil?

        execute(conn, position_args(q.join(" ")), params)
      end

      private def update(conn, queryable, query, query_hash)
        fields_values = instance_fields_and_values(query_hash)
        params = [] of DbValue | Array(DbValue)

        q = update_begin(queryable.table_name, fields_values)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        exec_execute(conn, position_args(q.join(" ")), fields_values[:values] + params)
      end

      private def delete_begin(table_name)
        q = ["DELETE FROM"]
        q.push "#{table_name}"
      end

      private def delete(conn, changeset)
        q = delete_begin(changeset.instance.class.table_name)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=$1"
        q.push "RETURNING *" if conn.is_a?(DB::Database)

        exec_execute(conn, q.join(" "), [changeset.instance.pkey_value])
      end

      private def delete(conn, queryable, query : Crecto::Repo::Query)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        exec_execute(conn, position_args(q.join(" ")), params)
      end

      private def wheres(queryable, query, params)
        q = ["WHERE"]
        where_clauses = [] of String

        query.wheres.each do |where|
          if where.is_a?(NamedTuple)
            where_clauses.push(add_where(where, params))
          elsif where.is_a?(Hash)
            where_clauses += add_where(where, queryable, params)
          end
        end
        q.push where_clauses.join(" AND ")
        q.join(" ")
      end

      private def or_wheres(queryable, query, params)
        q = ["WHERE"]
        where_clauses = [] of String

        query.or_wheres.each do |where|
          where_clauses += add_where(where.as(Hash), queryable, params)
        end
        q.push where_clauses.join(" OR")
        q.join(" ")
      end

      private def add_where(where : NamedTuple, params)
        where[:params].each { |param| params.push(param) }
        where[:clause]
      end

      private def add_where(where : Hash, queryable, params)
        where.keys.map do |key|
          [where[key]].flatten.uniq.each { |param| params.push(param) unless param.is_a?(Nil) }

          results = " #{queryable.table_name}.#{key.to_s}"
          results += if where[key].is_a?(Array)
                       if where[key].as(Array).size === 0
                         next " 1=0"
                       else
                         " IN (" + where[key].as(Array).uniq.map { |p| "?" }.join(", ") + ")"
                       end
                     elsif where[key].is_a?(Nil)
                       " IS NULL"
                     else
                       "=?"
                     end
        end
      end

      private def joins(queryable, query, params)
        joins = query.joins.map do |join|
          if queryable.through_key_for_association(join)
            join_through(queryable, join)
          else
            join_single(queryable, join)
          end
        end
        joins.join(" ")
      end

      private def join_single(queryable, join)
        association_klass = queryable.klass_for_association(join)

        q = ["INNER JOIN"]
        q.push association_klass.table_name
        q.push "ON"

        if queryable.association_type_for_association(join) == :belongs_to
          q.push association_klass.table_name + "." + association_klass.primary_key_field
        else
          q.push association_klass.table_name + "." + queryable.foreign_key_for_association(join).to_s
        end

        q.push "="

        if queryable.association_type_for_association(join) == :belongs_to
          q.push queryable.table_name + '.' + association_klass.foreign_key_for_association(queryable).to_s
        else
          q.push queryable.table_name + '.' + queryable.primary_key_field
        end

        q.join(" ")
      end

      private def join_through(queryable, join)
        association_klass = queryable.klass_for_association(join)
        join_klass = queryable.klass_for_association(queryable.through_key_for_association(join).as(Symbol))

        q = ["INNER JOIN"]
        q.push join_klass.table_name
        q.push "ON"
        q.push join_klass.table_name + "." + queryable.foreign_key_for_association(join).to_s
        q.push "="
        q.push queryable.table_name + "." + queryable.primary_key_field
        q.push "INNER JOIN"
        q.push association_klass.table_name
        q.push "ON"
        q.push association_klass.table_name + "." + association_klass.primary_key_field
        q.push "="
        q.push join_klass.table_name + "." + join_klass.foreign_key_for_association(association_klass).to_s
        q.join(" ")
      end

      private def order_bys(query)
        "ORDER BY #{query.order_bys.join(", ")}"
      end

      private def limit(query)
        "LIMIT #{query.limit}"
      end

      private def offset(query)
        "OFFSET #{query.offset}"
      end

      private def instance_fields_and_values(queryable_instance)
        instance_fields_and_values(queryable_instance.to_query_hash)
      end

      private def position_args(query_string : String)
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
