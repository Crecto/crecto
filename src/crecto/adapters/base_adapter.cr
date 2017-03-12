module Crecto
  module Adapters
    #
    # BaseAdapter module
    # Extended by actual adapters
    module BaseAdapter
      macro extended
        @@CRECTO_DB : DB::Database?
      end

      def get_db : DB::Database
        @@CRECTO_DB = DB.open(ENV[@@ENV_KEY]) if @@CRECTO_DB.nil?
        @@CRECTO_DB.as(DB::Database)
      end

      #
      # Query data store using a *query*
      #
      def run(operation : Symbol, queryable, query : Crecto::Repo::Query)
        case operation
        when :all
          all(queryable, query)
        when :delete_all
          delete(queryable, query, nil)
        end
      end

      def run(operation : Symbol, queryable, query : Crecto::Repo::Query, tx : DB::Transaction?)
        case operation
        when :delete_all
          delete(queryable, query, tx)
        end
      end

      def run(operation : Symbol, queryable, query : Crecto::Repo::Query, query_hash : Hash)
        case operation
        when :update_all
          update(queryable, query, query_hash, nil)
        end
      end

      def run(operation : Symbol, queryable, query : Crecto::Repo::Query, query_hash : Hash, tx : DB::Transaction?)
        case operation
        when :update_all
          update(queryable, query, query_hash, tx)
        end
      end

      #
      # Query data store using an *id*, returning a single record.
      #
      def run(operation : Symbol, queryable, id : Int32 | Int64 | String | Nil)
        case operation
        when :get
          get(queryable, id)
        end
      end

      #
      # Query data store using *sql*, returning multiple rows
      #
      def run(operation : Symbol, sql : String, params : Array(DbValue))
        case operation
        when :sql
          execute(position_args(sql), params)
        end
      end

      # Query data store in relation to a *queryable_instance* of Schema
      def run_on_instance(operation, changeset, tx : DB::Transaction?)
        case operation
        when :insert
          insert(changeset, tx)
        when :update
          update(changeset, tx)
        when :delete
          delete(changeset, tx)
        end
      end

      def run_on_instance(operation, changeset)
        resp = run_on_instance(operation, changeset, nil)
      end

      def execute(query_string, params)
        start = Time.now
        resp = get_db().query(query_string, params)
        DbLogger.log(query_string, Time.new - start, params)
        resp
      end

      def execute(query_string)
        start = Time.now
        resp = get_db().query(query_string)
        DbLogger.log(query_string, Time.new - start)
        resp
      end

      def aggregate(queryable, ag, field)
        @@CRECTO_DB = DB.open(ENV[@@ENV_KEY]) if @@CRECTO_DB.nil?
        @@CRECTO_DB.as(DB::Database).scalar(build_aggregate_query(queryable, ag, field))
      end

      def aggregate(queryable, ag, field, query : Crecto::Repo::Query)
        @@CRECTO_DB = DB.open(ENV[@@ENV_KEY]) if @@CRECTO_DB.nil?
        params = [] of DbValue | Array(DbValue)
        q = [build_aggregate_query(queryable, ag, field)]
        q.push joins(queryable, query, params) if query.joins.any?
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?
        q.push order_bys(query) if query.order_bys.any?
        q.push limit(query) unless query.limit.nil?
        q.push offset(query) unless query.offset.nil?

        @@CRECTO_DB.as(DB::Database).scalar(position_args(q.join(" ")), params)
      end

      private def build_aggregate_query(queryable, ag, field)
        "SELECT #{ag}(#{field}) from #{queryable.table_name}"
      end

      private def all(queryable, query)
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

        execute(position_args(q.join(" ")), params)
      end

      private def update(queryable, query, query_hash, tx : DB::Transaction?)
        fields_values = instance_fields_and_values(query_hash)
        params = [] of DbValue | Array(DbValue)

        q = update_begin(queryable.table_name, fields_values)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        exec_execute(position_args(q.join(" ")), fields_values[:values] + params, tx)
      end

      private def delete_begin(table_name)
        q = ["DELETE FROM"]
        q.push "#{table_name}"
      end

      private def delete(queryable, query : Crecto::Repo::Query, tx : DB::Transaction?)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        execute(position_args(q.join(" ")), params, tx)
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
          [where[key]].flatten.each { |param| params.push(param) }

          resp = " #{queryable.table_name}.#{key.to_s}"
          resp += if where[key].is_a?(Array)
                    " IN (" + where[key].as(Array).map { |p| "?" }.join(", ") + ")"
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
        q.push association_klass.table_name + "." + queryable.foreign_key_for_association(join).to_s
        q.push "="
        q.push queryable.table_name + '.' + queryable.primary_key_field
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
