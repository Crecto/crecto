module Crecto
  module Adapters
    #
    # Adapter module for MySQL
    #
    # Uses [crystal-mysql](https://github.com/crystal-lang/crystal-mysql) for now.
    #
    # Other adapters should follow this same pattern
    module Mysql
      @@ENV_KEY = "MYSQL_URL"
      extend BaseAdapter

      #
      # Query data store using *sql*, returning multiple rows
      #
      def self.run(operation : Symbol, sql : String, params : Array(DbValue))
        case operation
        when :sql
          execute(sql, params)
        end
      end

      def self.exec_execute(query_string, params, tx : DB::Transaction?)
        return exec_execute(query_string, params) if tx.nil?
        tx.connection.exec(query_string, params)
      end

      def self.exec_execute(query_string, params)
        get_db().exec(query_string, params)
      end

      def self.exec_execute(query_string)
        get_db().exec(query_string)
      end

      private def self.get(queryable, id)
        q = ["SELECT *"]
        q.push "FROM #{queryable.table_name}"
        q.push "WHERE #{queryable.primary_key_field}=?"
        q.push "LIMIT 1"

        execute(q.join(" "), [id])
      end

      private def self.insert(changeset, tx : DB::Transaction?)
        fields_values = instance_fields_and_values(changeset.instance)

        q = ["INSERT INTO"]
        q.push "#{changeset.instance.class.table_name}"
        q.push "(#{fields_values[:fields].join(", ")})"
        q.push "VALUES"
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"

        exec_execute(q.join(" "), fields_values[:values], tx)
        execute("SELECT * FROM #{changeset.instance.class.table_name} WHERE #{changeset.instance.class.primary_key_field} = LAST_INSERT_ID()")
      end

      private def self.update_begin(table_name, fields_values)
        q = ["UPDATE"]
        q.push "#{table_name}"
        q.push "SET"
        q.push fields_values[:fields].map { |field_value| "#{field_value}=?" }.join(", ")
        q
      end

      private def self.update(changeset, tx)
        fields_values = instance_fields_and_values(changeset.instance)

        q = update_begin(changeset.instance.class.table_name, fields_values)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"

        exec_execute(q.join(" "), fields_values[:values], tx)
        execute("SELECT * FROM #{changeset.instance.class.table_name} WHERE #{changeset.instance.class.primary_key_field} = #{changeset.instance.pkey_value}")
      end

      private def self.delete(changeset, tx : DB::Transaction?)
        q = delete_begin(changeset.instance.class.table_name)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}"

        sel = execute("SELECT * FROM #{changeset.instance.class.table_name} WHERE #{changeset.instance.class.primary_key_field}=#{changeset.instance.pkey_value}") if !tx.nil?
        return exec_execute(q.join(" "), tx) if !tx.nil?
        sel
      end

      private def self.delete(queryable, query, tx : DB::Transaction?)
        params = [] of DbValue | Array(DbValue)

        q = delete_begin(queryable.table_name)
        q.push wheres(queryable, query, params) if query.wheres.any?
        q.push or_wheres(queryable, query, params) if query.or_wheres.any?

        exec_execute(q.join(" "), params, tx)
      end

      private def self.wheres(queryable, query, params)
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

      private def self.or_wheres(queryable, query, params)
        q = ["WHERE"]
        where_clauses = [] of String

        query.or_wheres.each do |where|
          where_clauses += add_where(where.as(Hash), queryable, params)
        end
        q.push where_clauses.join(" OR")
        q.join(" ")
      end

      private def self.add_where(where : NamedTuple, params)
        where[:params].each { |param| params.push(param) }
        where[:clause]
      end

      private def self.add_where(where : Hash, queryable, params)
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

      private def self.joins(queryable, query, params)
        joins = query.joins.map do |join|
          if queryable.through_key_for_association(join)
            join_through(queryable, join)
          else
            join_single(queryable, join)
          end
        end
        joins.join(" ")
      end

      private def self.join_single(queryable, join)
        association_klass = queryable.klass_for_association(join)

        q = ["INNER JOIN"]
        q.push association_klass.table_name
        q.push "ON"
        q.push association_klass.table_name + "." + queryable.foreign_key_for_association(join).to_s
        q.push "="
        q.push queryable.table_name + '.' + queryable.primary_key_field
        q.join(" ")
      end

      private def self.join_through(queryable, join)
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
        {fields: query_hash.keys, values: query_hash.values.map { |v| v.is_a?(Time) ? v.to_s.split(" ")[0..1].join(" ") : v.as(DbValue) }}
      end

      private def self.instance_fields_and_values(queryable_instance)
        instance_fields_and_values(queryable_instance.to_query_hash)
      end

      private def self.position_args(query_string : String)
        query_string
      end
    end
  end
end
