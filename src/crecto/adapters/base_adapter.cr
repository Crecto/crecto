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
        begin
          if conn.is_a?(DB::Database)
            conn.query(query_string, params)
          else
            conn.connection.query(query_string, params)
          end
        ensure
          DbLogger.log(query_string, Time.new - start, params)
        end
      end

      def execute(conn, query_string)
        start = Time.now
        begin
          if conn.is_a?(DB::Database)
            conn.query(query_string)
          else
            conn.connection.query(query_string)
          end
        ensure
          DbLogger.log(query_string, Time.new - start)
        end
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
        q = String.build do |builder|
          builder <<
            "SELECT * FROM " << queryable.table_name <<
            " WHERE (" << queryable.primary_key_field << "=$1)"  <<
            " LIMIT 1"
        end

        execute(conn, q, [id])
      end

      private def insert(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = String.build do |builder|
          builder <<
            "INSERT INTO " << changeset.instance.class.table_name <<
            " (" << fields_values[:fields] << ')' <<
            " VALUES" <<
            " ("
          fields_values[:values].size.times do
            builder << "?, "
          end
          builder.back(2)
          builder << ") RETURNING *"
        end


        execute(conn, position_args(q), fields_values[:values])
      end

      def aggregate(conn, queryable, ag, field)
        q = String.build do |builder|
          build_aggregate_query(builder, queryable, ag, field)
        end

        conn.scalar(q)
      end

      def aggregate(conn, queryable, ag, field, query : Crecto::Repo::Query)
        params = [] of DbValue | Array(DbValue)
        q = String.build do |builder|
          build_aggregate_query(builder, queryable, ag, field)
          joins(builder, queryable, query, params)
          wheres(builder, queryable, query, params)
          or_wheres(builder, queryable, query, params)
          order_bys(builder, query)
          limit(builder, query)
          offset(builder, query)
        end

        start = Time.now
        query_string = position_args(q)
        results = conn.scalar(query_string, params)
        DbLogger.log(query_string, Time.new - start, params)
        results
      end

      private def build_aggregate_query(builder, queryable, ag, field)
        builder << " SELECT " << ag << '(' << queryable.table_name << '.' << field << ") FROM " << queryable.table_name
      end


      private def all(conn, queryable, query)
        params = [] of DbValue | Array(DbValue)

        q = String.build do |builder|
          builder << "SELECT"
          if query.distincts.nil?
            query.selects.each do |s|
              builder << ' ' << queryable.table_name << '.' << s << ','
            end

            builder.back(1)
          else
            builder << " DISTINCT " << query.distincts
          end

          builder << " FROM " << queryable.table_name
          joins(builder, queryable, query, params)
          wheres(builder, queryable, query, params)
          or_wheres(builder, queryable, query, params)
          order_bys(builder, query) 
          limit(builder, query)
          offset(builder, query)
          group_by(builder, query)
        end

        execute(conn, position_args(q), params)
      end

      private def update(conn, queryable, query, query_hash)
        fields_values = instance_fields_and_values(query_hash)
        params = [] of DbValue | Array(DbValue)

        q = String.build do |builder|
          update_begin(builder, queryable.table_name, fields_values)
          wheres(builder, queryable, query, params)
          or_wheres(builder, queryable, query, params)
        end

        exec_execute(conn, position_args(q), fields_values[:values] + params)
      end

      private def delete_begin(builder, table_name)
        builder << "DELETE FROM " << table_name
      end

      private def delete(conn, changeset)
        q = String.build do |builder|
          delete_begin(builder, changeset.instance.class.table_name)
          builder << " WHERE "
          builder << '(' << changeset.instance.class.primary_key_field << "=$1" << ')'
          builder << " RETURNING *" if conn.is_a?(DB::Database)
        end

        exec_execute(conn, q, [changeset.instance.pkey_value])
      end

      private def delete(conn, queryable, query : Crecto::Repo::Query)
        params = [] of DbValue | Array(DbValue)

        q = String.build do |builder|
          delete_begin(builder, queryable.table_name)

          wheres(builder, queryable, query, params) 
          or_wheres(builder, queryable, query, params)
        end

        exec_execute(conn, position_args(q), params)
      end

      private def wheres(builder, queryable, query, params)
        return if query.wheres.empty?

        builder << " WHERE "
        add_where_clauses(builder, queryable, query.wheres, params, " AND ")
      end

      private def or_wheres(builder, queryable, query, params)
        return if query.or_wheres.empty?

        builder << " WHERE "
        add_where_clauses(builder, queryable, query.or_wheres, params, " OR ")
      end

      private def add_where_clauses(builder, queryable, wheres, params, join_string)
        wheres.each do |where|
          if where.is_a?(NamedTuple)
            add_where(builder, where, params)
          elsif where.is_a?(Hash)
            add_where(builder, where, queryable, params, join_string)
          end

          builder << join_string
        end

        builder.back(join_string.bytesize)
      end

      private def add_where(builder, where : NamedTuple, params)
        where[:params].each { |param| params.push(param) }
        builder << '(' << where[:clause] << ')'
      end

      private def add_where(builder, where : Hash, queryable, params, join_string)
        where.keys.each do |key|
          [where[key]].flatten.uniq.each { |param| params.push(param) unless param.is_a?(Nil) }

          if where[key].is_a?(Array) && where[key].as(Array).size === 0
            builder << " 1=0" << join_string
            next
          end

          builder << " (" << queryable.table_name << '.' << key.to_s
          if where[key].is_a?(Array)
            builder << " IN ("
            where[key].as(Array).uniq.size.times do
              builder << "?, "
            end
            builder.back(2)
            builder << ')'
          elsif where[key].is_a?(Nil)
            builder << " IS NULL"
          else
            builder << "=?"
          end

          builder << ')' << join_string
        end

        builder.back(join_string.bytesize)
      end

      private def joins(builder, queryable, query, params)
        return if query.joins.empty?

        query.joins.each do |join|
          if join.is_a? Symbol
            if queryable.through_key_for_association(join)
              join_through(builder, queryable, join)
            else
              join_single(builder, queryable, join)
            end
          else
            builder << ' ' << join
          end
        end
      end

      private def join_single(builder, queryable, join)
        association_klass = queryable.klass_for_association(join)

        builder << " INNER JOIN " << association_klass.table_name << " ON "

        if queryable.association_type_for_association(join) == :belongs_to
          builder << association_klass.table_name << '.' << association_klass.primary_key_field
        else
          builder << association_klass.table_name << '.' << queryable.foreign_key_for_association(join).to_s
        end

        builder << " = "

        if queryable.association_type_for_association(join) == :belongs_to
          builder << queryable.table_name << '.' << association_klass.foreign_key_for_association(queryable).to_s
        else
          builder << queryable.table_name << '.' << queryable.primary_key_field
        end
      end

      private def join_through(builder, queryable, join)
        association_klass = queryable.klass_for_association(join)
        join_klass = queryable.klass_for_association(queryable.through_key_for_association(join).as(Symbol))

        builder << " INNER JOIN " << join_klass.table_name << " ON "
        builder << join_klass.table_name << '.' << queryable.foreign_key_for_association(join).to_s
        builder << " = "
        builder << queryable.table_name << '.' << queryable.primary_key_field
        builder << " INNER JOIN " << association_klass.table_name << " ON "
        builder << association_klass.table_name << '.' << association_klass.primary_key_field
        builder << " = "
        builder << join_klass.table_name << '.' << join_klass.foreign_key_for_association(association_klass).to_s
      end

      private def order_bys(builder, query)
        return if query.order_bys.empty?

        builder << " ORDER BY "
        query.order_bys.each do |order_by|
          builder << order_by << ", "
        end

        builder.back(2)
      end

      private def limit(builder, query)
        return unless query.limit

        builder << " LIMIT " << query.limit
      end

      private def offset(builder, query)
        return unless query.offset

        builder << " OFFSET " << query.offset
      end

      private def group_by(builder, query)
        return unless query.group_bys

        builder << " GROUP BY " << query.group_bys
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
