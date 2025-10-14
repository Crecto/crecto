module Crecto
  module Adapters
    #
    # PreparedStatementCache for managing prepared statement lifecycle
    class PreparedStatementCache
      @cache : Hash(String, DB::Statement)
      @access_times : Hash(String, Time)
      @max_size : Int32
      @cleanup_count : Int64
      @hit_count : Int64
      @miss_count : Int64
      @total_prepared : Int64

      def initialize(@max_size = 100)
        @cache = {} of String => DB::Statement
        @access_times = {} of String => Time
        @cleanup_count = 0_i64
        @hit_count = 0_i64
        @miss_count = 0_i64
        @total_prepared = 0_i64
      end

      def get_statement(conn : DB::Database | DB::Transaction, query_hash : String) : DB::Statement
        current_time = Time.local

        if @cache.has_key?(query_hash)
          @access_times[query_hash] = current_time
          @hit_count += 1
          return @cache[query_hash]
        end

        cleanup if @cache.size >= @max_size

        begin
          statement = conn.prepare(query_hash)
          @cache[query_hash] = statement
          @access_times[query_hash] = current_time
          @total_prepared += 1
          @miss_count += 1
          statement
        rescue ex : Exception
          # Log statement preparation failures
          DbLogger.log_error("PREPARED_STATEMENT_ERROR", "Failed to prepare statement: #{ex.message}", {
            "query_hash" => query_hash[0..100],
            "cache_size" => @cache.size.to_s,
            "max_size" => @max_size.to_s
          })
          raise ex
        end
      end

      def cleanup
        return if @cache.size < @max_size

        old_size = @cache.size
        @cleanup_count += 1

        # Remove least recently used statements
        sorted_by_access = @access_times.to_a.sort_by(&.[1])
        to_remove = sorted_by_access[0..(@cache.size / 4)]

        to_remove.each do |key, _|
          @cache.delete(key)
          @access_times.delete(key)
        end

        # Log cleanup activity
        DbLogger.log_error("CACHE_CLEANUP", "Cleaned up prepared statement cache", {
          "removed_count" => (old_size - @cache.size).to_s,
          "cache_size" => @cache.size.to_s,
          "cleanup_count" => @cleanup_count.to_s
        }) if @cleanup_count % 100 == 0  # Log every 100th cleanup
      end

      def clear
        @cache.clear
        @access_times.clear
      end

      def size
        @cache.size
      end

      def max_size
        @max_size
      end

      # Connection pool health monitoring methods
      def hit_rate
        total = @hit_count + @miss_count
        total > 0 ? (@hit_count.to_f64 / total.to_f64 * 100).round(2) : 0.0
      end

      def stats
        {
          "cache_size" => @cache.size,
          "max_size" => @max_size,
          "hit_count" => @hit_count,
          "miss_count" => @miss_count,
          "hit_rate_percent" => hit_rate,
          "total_prepared" => @total_prepared,
          "cleanup_count" => @cleanup_count,
          "memory_estimate_bytes" => @cache.size * 100  # Rough estimate
        }
      end

      def health_status
        cache_utilization = (@cache.size.to_f64 / @max_size.to_f64 * 100).round(2)

        {
          "status" => cache_utilization > 90 ? "warning" : cache_utilization > 75 ? "caution" : "healthy",
          "cache_utilization_percent" => cache_utilization,
          "hit_rate_percent" => hit_rate,
          "recommendations" => generate_recommendations(cache_utilization, hit_rate)
        }
      end

      private def generate_recommendations(utilization : Float64, hit_rate : Float64)
        recommendations = [] of String

        if utilization > 90
          recommendations << "Consider increasing max_size to reduce cache pressure"
        end

        if hit_rate < 50
          recommendations << "Low hit rate suggests cache size may be too small for workload"
        end

        if @cleanup_count > 1000
          recommendations << "High cleanup frequency indicates cache churn"
        end

        recommendations
      end
    end

    #
    # BaseAdapter module
    # Extended by actual adapters
    module BaseAdapter
      # Time formatting configuration class variable
      @@time_format = "%F %H:%M:%S.%L"

      # Get the current Time format used for database storage
      def self.time_format
        @@time_format
      end

      # Set the Time format used for database storage
      def self.time_format=(format : String)
        @@time_format = format
      end

      macro included
        @@statement_cache : PreparedStatementCache?
        @@connection_stats = {
          "active_connections" => 0,
          "total_queries" => 0,
          "cache_hits" => 0,
          "cache_misses" => 0,
          "memory_usage_bytes" => 0,
          "connection_errors" => 0,
          "retry_attempts" => 0,
          "recovery_attempts" => 0,
          "last_error_time" => Time.local,
          "last_recovery_time" => Time.local,
          "total_operations" => 0,
          "start_time" => Time.local
        }

  
        def self.statement_cache
          @@statement_cache ||= PreparedStatementCache.new
        end

        def self.initialize_statement_cache(max_size = 100)
          @@statement_cache = PreparedStatementCache.new(max_size)
        end

        def self.connection_stats
          @@connection_stats
        end

        def self.track_connection_usage
          @@connection_stats["active_connections"] = @@connection_stats["active_connections"].as(Int32) + 1
          begin
            yield
          ensure
            @@connection_stats["active_connections"] = @@connection_stats["active_connections"].as(Int32) - 1
          end
        end

        def self.track_memory_usage
          before_memory = GC.stats.heap_size
          begin
            yield
          ensure
            after_memory = GC.stats.heap_size
            @@connection_stats["memory_usage_bytes"] = after_memory - before_memory
          end
        end

        protected def self.execute_with_cache(conn : DB::Database | DB::Transaction, query_string : String, params : Array(DbValue)? = nil)
          query_hash = "#{query_string}:#{params.hash}"
          @@connection_stats["total_queries"] = @@connection_stats["total_queries"].as(Int32) + 1
          @@connection_stats["total_operations"] = @@connection_stats["total_operations"].as(Int32) + 1

          if cached_statement = statement_cache.get_statement(conn, query_string)
            @@connection_stats["cache_hits"] = @@connection_stats["cache_hits"].as(Int32) + 1
            start = Time.local
            begin
              if params
                conn.query(query_string, args: params)
              else
                conn.query(query_string)
              end
            ensure
              DbLogger.log(query_string, Time.local - start, params || [] of DbValue)
            end
          else
            @@connection_stats["cache_misses"] = @@connection_stats["cache_misses"].as(Int32) + 1
            if params
              execute(conn, query_string, params)
            else
              execute(conn, query_string)
            end
          end
        end

        # Connection pool health monitoring and recovery methods
        def self.connection_pool_health
          {
            "connection_stats" => @@connection_stats,
            "statement_cache_stats" => statement_cache.stats,
            "statement_cache_health" => statement_cache.health_status,
            "uptime_seconds" => (Time.local - @@connection_stats["start_time"].as(Time)).total_seconds.round(2),
            "operations_per_second" => calculate_operations_per_second
          }
        end

        def self.calculate_operations_per_second
          uptime_seconds = (Time.local - @@connection_stats["start_time"].as(Time)).total_seconds
          uptime_seconds > 0 ? (@@connection_stats["total_operations"].as(Int32) / uptime_seconds).round(2) : 0.0
        end

        def self.track_connection_error(error_class : String, error_message : String)
          @@connection_stats["connection_errors"] = @@connection_stats["connection_errors"].as(Int32) + 1
          @@connection_stats["last_error_time"] = Time.local

          # Log connection error with context
          DbLogger.log_error("CONNECTION_ERROR", error_message, {
            "error_class" => error_class,
            "total_errors" => @@connection_stats["connection_errors"].to_s,
            "connection_pool_health" => connection_pool_health.to_s
          })

          # Trigger recovery if error rate is high
          attempt_connection_recovery if should_attempt_recovery?
        end

        def self.track_retry_attempt
          @@connection_stats["retry_attempts"] = @@connection_stats["retry_attempts"].as(Int32) + 1
        end

        def self.should_attempt_recovery?
          error_rate = calculate_error_rate
          recent_errors = recent_error_count

          # Attempt recovery if error rate > 10% or more than 5 errors in last minute
          error_rate > 10.0 || recent_errors > 5
        end

        def self.calculate_error_rate
          total_ops = @@connection_stats["total_operations"].as(Int32)
          total_errors = @@connection_stats["connection_errors"].as(Int32)

          return 0.0 if total_ops == 0
          (total_errors.to_f64 / total_ops.to_f64 * 100).round(2)
        end

        def self.recent_error_count
          last_error_time = @@connection_stats["last_error_time"].as(Time)
          (Time.local - last_error_time).total_seconds < 60 ? 1 : 0
        end

        def self.attempt_connection_recovery
          @@connection_stats["recovery_attempts"] = @@connection_stats["recovery_attempts"].as(Int32) + 1
          @@connection_stats["last_recovery_time"] = Time.local

          DbLogger.log_error("CONNECTION_RECOVERY", "Attempting automatic connection pool recovery", {
            "recovery_attempts" => @@connection_stats["recovery_attempts"].to_s,
            "error_rate" => calculate_error_rate.to_s
          })

          # Clear statement cache to free up resources
          statement_cache.clear

          # Force garbage collection to free memory
          GC.collect

          DbLogger.log_error("CONNECTION_RECOVERY_COMPLETE", "Connection pool recovery completed", {
            "cache_cleared" => "true",
            "memory_freed" => "true"
          })
        end

        def self.get_connection_pool_recommendations
          health = connection_pool_health
          recommendations = [] of String

          cache_health = health["statement_cache_health"].as(Hash)
          status = cache_health["status"].as(String)
          hit_rate = cache_health["hit_rate_percent"].as(Float64)
          utilization = cache_health["cache_utilization_percent"].as(Float64)

          case status
          when "warning"
            recommendations << "Connection pool under stress - consider increasing resources"
          when "caution"
            recommendations << "Monitor connection pool closely for performance issues"
          end

          if hit_rate < 50
            recommendations << "Low prepared statement cache hit rate - consider cache size optimization"
          end

          if utilization > 80
            recommendations << "High cache utilization - may need to increase max cache size"
          end

          error_rate = calculate_error_rate
          if error_rate > 5
            recommendations << "High connection error rate (#{error_rate}%) - check database connectivity"
          end

          ops_per_sec = health["operations_per_second"].as(Float64)
          if ops_per_sec > 1000
            recommendations << "High operation rate - ensure connection pool is adequately sized"
          end

          recommendations
        end
      end
      #
      # Query data store using a *query*
      #
      def run(conn : DB::Database | DB::Transaction, operation : Symbol, queryable, query : Crecto::Repo::Query)
        case operation
        when :all
          all(conn, queryable, query)
        when :delete_all
          delete(conn, queryable, query)
        else
          raise Exception.new("invalid operation passed to run")
        end
      end

      def run(conn : DB::Database | DB::Transaction, operation : Symbol, queryable, query : Crecto::Repo::Query, query_hash : Hash)
        case operation
        when :update_all
          update(conn, queryable, query, query_hash)
        else
          raise Exception.new("invalid operation passed to run")
        end
      end

      #
      # Query data store using an *id*, returning a single record.
      #
      def run(conn : DB::Database | DB::Transaction, operation : Symbol, queryable, id : PkeyValue)
        case operation
        when :get
          get(conn, queryable, id)
        else
          raise Exception.new("invalid operation passed to run")
        end
      end

      #
      # Query data store using *sql*, returning multiple rows
      #
      def run(conn : DB::Database | DB::Transaction, operation : Symbol, sql : String, params : Array(DbValue))
        case operation
        when :sql
          execute(conn, position_args(sql), params)
        else
          raise Exception.new("invalid operation passed to run")
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
        else
          raise Exception.new("invalid operation passed to run_on_instance")
        end
      end

      def execute(conn, query_string, params)
        start = Time.local
        begin
          # Add SQL capture for tests
          Crecto::Adapters.sqls << query_string

          # Validate parameter count to prevent IndexError
          param_count = query_string.count('?')
          if param_count != params.size
            error_msg = "Parameter count mismatch: expected #{param_count} parameters, got #{params.size}. Query: #{query_string}"
            context = {
            "params" => params.map(&.to_s),
            "query" => query_string
          }
          DbLogger.log_error("PARAMETER_VALIDATION_ERROR", error_msg, context)
            raise ArgumentError.new(error_msg)
          end

          if conn.is_a?(DB::Database)
            conn.query(query_string, args: params)
          else
            conn.connection.query(query_string, args: params)
          end
        rescue ex : ArgumentError
          # Re-raise ArgumentError with enhanced context
          context = {
            "query" => query_string,
            "param_count" => params.size.to_s,
            "expected_placeholders" => query_string.count('?').to_s,
            "params" => params.map { |p| p.is_a?(String) ? "#{p[0..20]}#{p.size > 20 ? "..." : ""}" : p.to_s }
          }
          DbLogger.log_error("INSERT_ARGUMENT_ERROR", ex.message || "Unknown argument error", context)
          raise ex
        rescue ex : Exception
          # Track connection-related errors for recovery monitoring
          if is_connection_error?(ex)
            # Use DbLogger for connection error tracking since we're in an instance method
            DbLogger.log_error("CONNECTION_ERROR_TRACK", "Connection error during execute", {
              "error_class" => ex.class.name,
              "error_message" => ex.message || "Connection error during execute",
              "query" => query_string[0..100],  # Limit query length in logs
              "connection_type" => conn.is_a?(DB::Database) ? "database" : "transaction"
            })
          end

          # Enhanced error logging for all other exceptions during insert operations
          context = {
            "query" => query_string,
            "param_count" => params.size.to_s,
            "error_class" => ex.class.name,
            "connection_type" => conn.is_a?(DB::Database) ? "database" : "transaction"
          }
          DbLogger.log_error("INSERT_EXECUTION_ERROR", ex.message || "Unknown execution error", context)
          raise ex
        ensure
          DbLogger.log(query_string, Time.local - start, params)
        end
      end

      def execute(conn, query_string)
        start = Time.local
        begin
          # Add SQL capture for tests
          Crecto::Adapters.sqls << query_string

          if conn.is_a?(DB::Database)
            conn.query(query_string)
          else
            conn.connection.query(query_string)
          end
        ensure
          DbLogger.log(query_string, Time.local - start)
        end
      end

      def exec_execute(conn, query_string, params)
        return execute(conn, query_string, params) if conn.is_a?(DB::Database)

        # Validate parameter count to prevent IndexError
        param_count = query_string.count('?')
        if param_count != params.size
          error_msg = "Parameter count mismatch: expected #{param_count} parameters, got #{params.size}. Query: #{query_string}"
          context = {
            "params" => params.map(&.to_s),
            "query" => query_string
          }
          DbLogger.log_error("EXEC_PARAMETER_VALIDATION_ERROR", error_msg, context)
          raise ArgumentError.new(error_msg)
        end

        begin
          conn.connection.exec(query_string, args: params)
        rescue ex : Exception
          # Enhanced error logging for exec operations
          context = {
            "query" => query_string,
            "param_count" => params.size.to_s,
            "error_class" => ex.class.name,
            "operation" => "exec_execute"
          }
          DbLogger.log_error("EXEC_INSERT_ERROR", ex.message || "Unknown exec error", context)
          raise ex
        end
      end

      def exec_execute(conn, query_string)
        return execute(conn, query_string) if conn.is_a?(DB::Database)
        conn.connection.exec(query_string)
      end

      private def get(conn, queryable, id)
        q = String.build do |builder|
          builder <<
            "SELECT * FROM " << queryable.table_name <<
            " WHERE (" << queryable.primary_key_field << "=$1)" <<
            " LIMIT 1"
        end

        execute(conn, q, [id])
      end

      private def insert(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = String.build do |builder|
          builder <<
            "INSERT INTO " << changeset.instance.class.table_name <<
            " (" << fields_values[:fields].join(", ") << ')' <<
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
          where_expression(builder, queryable, query, params)
          order_bys(builder, query)
          limit(builder, query)
          offset(builder, query)
        end

        start = Time.local
        query_string = position_args(q)
        results = conn.scalar(query_string, args: params)
        DbLogger.log(query_string, Time.local - start, params)
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
          where_expression(builder, queryable, query, params)
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
          where_expression(builder, queryable, query, params)
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

          where_expression(builder, queryable, query, params)
        end

        exec_execute(conn, position_args(q), params)
      end

      private def where_expression(builder, queryable, query, params)
        return if query.where_expression.empty?

        builder << " WHERE "
        add_where_clauses(builder, queryable, query.where_expression, params)
      end

      private def add_where_clauses(builder, queryable, where_expression : Crecto::Repo::Query::InitialExpression, params, join_string = nil)
        builder << "1=1 "
        builder << join_string unless join_string.nil?
      end

      private def add_where_clauses(builder, queryable, where_expression : Crecto::Repo::Query::AtomExpression, params, join_string = nil)
        add_where_clause(builder, queryable, where_expression.atom, params, join_string || " AND ")
        builder << join_string unless join_string.nil?
      end

      private def add_where_clauses(builder, queryable, where_expression : Crecto::Repo::Query::AndExpression, params, join_string = nil)
        builder << '('
        add_where_expressions(builder, queryable, where_expression.expressions, params, " AND ")
        builder << ')'
        builder << join_string unless join_string.nil?
      end

      private def add_where_clauses(builder, queryable, where_expression : Crecto::Repo::Query::OrExpression, params, join_string = nil)
        builder << '('
        add_where_expressions(builder, queryable, where_expression.expressions, params, " OR ")
        builder << ')'
        builder << join_string unless join_string.nil?
      end

      private def add_where_expressions(builder, queryable, where_expressions, params, join_string)
        where_expressions.each do |expression|
          add_where_clauses(builder, queryable, expression, params, join_string)
        end

        builder.back(join_string.bytesize)
      end

      private def add_where_clause(builder, queryable, where, params, join_string)
        if where.is_a?(NamedTuple)
          add_where(builder, where, params, join_string)
        elsif where.is_a?(Hash)
          add_where(builder, where, queryable, params, join_string)
        end
      end

      private def add_where(builder, where : NamedTuple, params, join_string)
        where[:params].each { |param| params.push(param) }
        builder << '(' << where[:clause] << ')'
      end

      private def add_where(builder, where : Hash, queryable, params, join_string)
        where.keys.each do |key|
          [where[key]].flatten.uniq.each { |param| params.push(param) unless param.is_a?(Nil) }

          if where[key].is_a?(Array) && where[key].as(Array).size === 0
            builder << "1=0" << join_string
            next
          end

          builder << '(' << queryable.table_name << '.' << key.to_s

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
        return "" if association_klass.nil?

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
        return "" if join_klass.nil? || association_klass.nil?

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
        return query_string unless query_string.includes?("?")

        query = ""
        chunks = query_string.split("?")
        chunks.each_with_index do |chunk, i|
          query += chunk
          query += "$#{i + 1}" unless i == chunks.size - 1
        end
        query
      end

      # Format Time values consistently across all database adapters
      # Converts Time to UTC and formats as database-compatible string
      # Includes error handling for extreme or invalid Time values
      def self.format_time_for_db(time : Time) : String
        begin
          # Validate Time is within reasonable database range
          # Most databases support dates from 1970-01-01 to 2038-01-19 for 32-bit timestamps
          # Some support wider ranges, but we'll use conservative defaults
          unix_time = time.to_unix

          # Check for extreme values that might cause database errors
          if unix_time < -62135596800 || unix_time > 2147483647  # ~1900 to 2038
            # Clamp to reasonable range to prevent database errors
            safe_time = unix_time < 0 ? Time.unix(0) : Time.unix(2147483647)
            DbLogger.log_error("TIME_VALUE_CLAMPED", "Time value clamped to prevent database error", {
              "original_time" => time.to_s,
              "original_unix" => unix_time.to_s,
              "clamped_time" => safe_time.to_s,
              "clamped_unix" => safe_time.to_unix.to_s
            })
            time = safe_time
          end

          time.to_utc.to_s(@@time_format)
        rescue ex : Exception
          # If Time formatting fails, log the error and use a safe default
          DbLogger.log_error("TIME_FORMAT_ERROR", "Failed to format Time value, using default", {
            "error_message" => ex.message || "Unknown Time formatting error",
            "error_class" => ex.class.name,
            "original_time" => time.inspect
          })
          # Return a safe default timestamp (current time in UTC)
          Time.utc.to_s(@@time_format)
        end
      end

      private def is_connection_error?(ex : Exception)
        # Check for common connection-related error patterns
        error_message = ex.message.to_s.downcase

        connection_error_patterns = [
          "connection", "pool", "timeout", "socket", "network",
          "broken pipe", "connection refused", "connection reset",
          "too many connections", "connection exhausted", "database locked"
        ]

        error_classes = [
          "DB::ConnectionError", "DB::PoolTimeout", "DB::PoolResourceLost",
          "SQLite3::Exception", "MySQL::Error", "PG::ConnectionError"
        ]

        # Check error class
        return true if error_classes.any? { |klass| ex.class.name.includes?(klass) }

        # Check error message
        connection_error_patterns.any? { |pattern| error_message.includes?(pattern) }
      end
    end
  end
end
