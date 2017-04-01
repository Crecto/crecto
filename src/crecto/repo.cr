module Crecto
  # A repository maps to an underlying data store, controlled by the adapter.
  module Repo
    # Return a list of *queryable* instances using *query*
    #
    # ```
    # query = Query.where(name: "fred")
    # users = Repo.all(User, query)
    # ```
    def all(queryable, query : Query? = Query.new, **opts) : Array
      q = config.adapter.run(config.get_connection, :all, queryable, query).as(DB::ResultSet)

      results = queryable.from_rs(q.as(DB::ResultSet))

      if query.preloads.any?
        add_preloads(results, queryable, query.preloads)
      end

      results
    end

    # Return a list of *queryable* instances
    #
    # ```
    # user = Crecto::Repo.get(User, 1)
    # posts = Repo.all(user, :posts)
    # ```
    def all(queryable_instance, association_name : Symbol) : Array
      query = Crecto::Repo::Query.where(queryable_instance.class.foreign_key_for_association(association_name), queryable_instance.pkey_value)
      all(queryable_instance.class.klass_for_association(association_name), query)
    end

    # Returns a list of *queryable* instances.  Accepts an optional `query`
    #
    # ```
    # users = Crecto::Repo.all(User)
    # ```
    def all(queryable, query = Query.new) : Array
      q = config.adapter.run(config.get_connection, :all, queryable, query).as(DB::ResultSet)
      results = queryable.from_rs(q)
      results
    end

    # Return a single nilable insance of *queryable* by primary key with *id*.
    #
    # ```
    # user = Repo.get(User, 1)
    # ```
    def get(queryable, id)
      q = config.adapter.run(config.get_connection, :get, queryable, id).as(DB::ResultSet)
      results = queryable.from_rs(q)
      results.first if results.any?
    end

    # Return a single insance of *queryable* by primary key with *id*.
    # Raises `NoResults` error if the record does not exist
    #
    # ```
    # user = Repo.get(User, 1)
    # ```
    def get!(queryable, id)
      if result = get(queryable, id)
        result
      else
        raise NoResults.new("No Results")
      end
    end

    # Return a single nilable insance of *queryable* by primary key with *id*.
    # Can pass a Query for the purpose of preloading associations
    #
    # ```
    # query = Query.preload(:posts)
    # user = Repo.get(User, 1, query)
    # ```
    def get(queryable, id, query : Query)
      q = config.adapter.run(config.get_connection, :get, queryable, id).as(DB::ResultSet)
      results = queryable.from_rs(q)

      if results.any?
        if query.preloads.any?
          add_preloads(results, queryable, query.preloads)
        end

        results.first
      end
    end

    # Return a single insance of *queryable* by primary key with *id*.
    # Can pass a Query for the purpose of preloading associations
    # Raises `NoResults` error if the record does not exist
    #
    # ```
    # query = Query.preload(:posts)
    # user = Repo.get(User, 1, query)
    # ```
    def get!(queryable, id, query : Query)
      if result = get(queryable, id, query : Query)
        result
      else
        raise NoResults.new("No Results")
      end
    end

    # Return a single nilable instance of *queryable*
    #
    # ```
    # user = Crecto::Repo.get(User, 1)
    # post = Repo.get(user, :post)
    # ```
    def get(queryable_instance, association_name : Symbol)
      results = all(queryable_instance, association_name)
      results.first if results.any?
    end

    # Return a single instance of *queryable*
    # Raises `NoResults` error if the record does not exist
    #
    # ```
    # user = Crecto::Repo.get(User, 1)
    # post = Repo.get(user, :post)
    # ```
    def get!(queryable_instance, association_name : Symbol)
      if result = get(queryable_instance, association_name : Symbol)
        result
      else
        raise NoResults.new("No Results")
      end
    end

    # Return a single nilable instance of *queryable* using the *query* param
    #
    # ```
    # user = Repo.get_by(User, name: "fred", age: 21)
    # ```
    def get_by(queryable, **opts)
      q = config.adapter.run(config.get_connection, :all, queryable, Query.where(**opts).limit(1)).as(DB::ResultSet)
      results = queryable.from_rs(q)
      results.first if results.any?
    end

    # Return a single instance of *queryable* using the *query* param
    # Raises `NoResults` error if the record does not exist
    #
    # ```
    # user = Repo.get_by(User, name: "fred", age: 21)
    # ```
    def get_by!(queryable, **opts)
      if result = get_by(queryable, **opts)
        result
      else
        raise NoResults.new("No Results")
      end
    end

    # Insert a schema instance into the data store.
    #
    # ```
    # user = User.new
    # Repo.insert(user)
    # ```
    def insert(queryable_instance, tx : DB::Transaction?)
      changeset = queryable_instance.class.changeset(queryable_instance)
      return changeset unless changeset.valid?

      changeset.instance.updated_at_to_now
      changeset.instance.created_at_to_now

      query = config.adapter.run_on_instance(tx || config.get_connection, :insert, changeset)

      if query.nil?
        changeset.add_error("insert_error", "Insert Failed")
      elsif config.adapter == Crecto::Adapters::Postgres || (config.adapter == Crecto::Adapters::Mysql && tx.nil?) ||
            (config.adapter == Crecto::Adapters::SQLite3 && tx.nil?)
        new_instance = changeset.instance.class.from_rs(query.as(DB::ResultSet)).first
        changeset = new_instance.class.changeset(new_instance) if new_instance
      end

      changeset.action = :insert
      changeset
    end

    def insert(queryable_instance)
      insert(queryable_instance, nil)
    end

    # Insert a changeset instance into the data store.
    #
    # ```
    # user = User.new
    # changeset = User.changeset(user)
    # Repo.insert(changeset)
    # ```
    def insert(changeset : Crecto::Changeset::Changeset)
      insert(changeset.instance)
    end

    # Update a shema instance in the data store.
    #
    # ```
    # Repo.update(user)
    # ```
    def update(queryable_instance, tx : DB::Transaction?)
      changeset = queryable_instance.class.changeset(queryable_instance)
      return changeset unless changeset.valid?

      changeset.instance.updated_at_to_now

      query = config.adapter.run_on_instance(tx || config.get_connection, :update, changeset)

      if query.nil?
        changeset.add_error("update_error", "Update Failed")
      else
        new_instance = changeset.instance.class.from_rs(query.as(DB::ResultSet)).first
        changeset = new_instance.class.changeset(new_instance) if new_instance
      end

      changeset.action = :update
      changeset
    end

    def update(queryable_instance)
      update(queryable_instance, nil)
    end

    # Update a changeset instance in the data store.
    #
    # ```
    # Repo.update(changeset)
    # ```
    def update(changeset : Crecto::Changeset::Changeset)
      update(changeset.instance)
    end

    # Update multipile records with a single query
    #
    # ```
    # query = Crecto::Repo::Query.where(name: "Ted", count: 0)
    # Repo.update_all(User, query, {count: 1, date: Time.now})
    # ```
    def update_all(queryable, query, update_hash : Hash, tx : DB::Transaction?)
      config.adapter.run(tx || config.get_connection, :update_all, queryable, query, update_hash)
    end

    def update_all(queryable, query, update_hash : Hash)
      update_all(queryable, query, update_hash, nil)
    end

    def update_all(queryable, query, update_hash : NamedTuple, tx : DB::Transaction?)
      update_all(queryable, query, update_hash.to_h, tx)
    end

    def update_all(queryable, query, update_hash : NamedTuple)
      update_all(queryable, query, update_hash, nil)
    end

    # Delete a shema instance from the data store.
    #
    # ```
    # Repo.delete(user)
    # ```
    def delete(queryable_instance, tx : DB::Transaction?)
      changeset = queryable_instance.class.changeset(queryable_instance)
      return changeset unless changeset.valid?

      check_dependents(changeset, tx)
      query = config.adapter.run_on_instance(tx || config.get_connection, :delete, changeset)

      if query.nil?
        changeset.add_error("delete_error", "Delete Failed")
      end

      changeset.action = :delete
      changeset
    end

    def delete(queryable_instance)
      delete(queryable_instance, nil)
    end

    # Delete a changeset instance from the data store.
    #
    # ```
    # Repo.delete(changeset)
    # ```
    def delete(changeset : Crecto::Changeset::Changeset)
      delete(changeset.instance)
    end

    # Delete multipile records with a single query
    #
    # ```
    # query = Crecto::Repo::Query.where(name: "Fred")
    # Repo.delete_all(User, query)
    # ```
    def delete_all(queryable, query : Query?, tx : DB::Transaction?)
      query = Query.new if query.nil?
      check_dependents(queryable, query, tx)
      config.adapter.run(tx || config.get_connection, :delete_all, queryable, query)
    end

    def delete_all(queryable, query = Query.new)
      delete_all(queryable, query, nil)
    end

    # Run aribtrary sql queries. `query` will cast the output as that
    # object. In this example, `query` will try to cast the
    # output as `User`. If query results happen to error nil is
    # returned
    #
    # ```
    # Repo.query(User, "select * from users where id > ?", [30])
    # ```
    def query(queryable, sql : String, params = [] of DbValue) : Array
      q = config.adapter.run(config.get_connection, :sql, sql, params).as(DB::ResultSet)
      results = queryable.from_rs(q)
      results
    end

    # Run aribtrary sql. `query` will pass a PG::ResultSet as
    # the return value once the query has been executed. Arguments
    # are defined as `?` and are interpolated to escape whats being
    # passed. `query` can run without parameters as well.
    #
    # ```
    # query = Crecto::Repo.query("select * from users where id = ?", [30])
    # ```
    def query(sql : String, params = [] of DbValue) : DB::ResultSet
      config.adapter.run(config.get_connection, :sql, sql, params).as(DB::ResultSet)
    end

    def transaction(multi : Crecto::Multi)
      if multi.changesets_valid?
        total_size = multi.inserts.size + multi.deletes.size + multi.delete_alls.size + multi.updates.size + multi.update_alls.size
        config.get_connection.transaction do |tx|
          (1..total_size).each do |x|
            inserts = multi.inserts.select { |i| i[:sortorder] == x }
            begin
              insert(inserts[0][:instance], tx) && next if inserts.any?
            rescue ex : Exception
              multi.errors = [{:message => "#{ex.message}", :queryable => "#{inserts[0][:instance].class}", :failed_operation => "insert"}]
              tx.rollback && break
            end

            deletes = multi.deletes.select { |i| i[:sortorder] == x }
            begin
              delete(deletes[0][:instance], tx) && next if deletes.any?
            rescue ex : Exception
              multi.errors = [{:message => "#{ex.message}", :queryable => "#{deletes[0][:instance].class}", :failed_operation => "delete"}]
              tx.rollback && break
            end

            delete_alls = multi.delete_alls.select { |i| i[:sortorder] == x }
            begin
              delete_all(delete_alls[0][:queryable], delete_alls[0][:query], tx) && next if delete_alls.any?
            rescue ex : Exception
              multi.errors = [{:message => "#{ex.message}", :queryable => "#{delete_alls[0][:queryable]}", :failed_operation => "delete_all"}]
              tx.rollback && break
            end

            updates = multi.updates.select { |i| i[:sortorder] == x }
            begin
              update(updates[0][:instance], tx) && next if updates.any?
            rescue ex : Exception
              multi.errors = [{:message => "#{ex.message}", :queryable => "#{updates[0][:instance].class}", :failed_operation => "update"}]
              tx.rollback && break
            end

            update_alls = multi.update_alls.select { |i| i[:sortorder] == x }
            begin
              update_all(update_alls[0][:queryable], update_alls[0][:query], update_alls[0][:update_hash], tx) if update_alls.any?
            rescue ex : Exception
              multi.errors = [{:message => "#{ex.message}", :queryable => "#{update_alls[0][:queryable]}", :failed_operation => "update_all"}]
              tx.rollback && break
            end
          end
        end
      end
      multi
    end

    # Calculate the given aggregate `aggregate_function` over the given `field`
    # Aggregate `aggregate_function` must be one of (:avg, :count, :max, :min:, :sum)
    def aggregate(queryable, aggregate_function : Symbol, field : Symbol)
      raise InvalidOption.new("Aggregate must be one of :avg, :count, :max, :min:, :sum") unless [:avg, :count, :max, :min, :sum].includes?(aggregate_function)

      config.adapter.aggregate(config.get_connection, queryable, aggregate_function, field)
    end

    def aggregate(queryable, aggregate_function : Symbol, field : Symbol, query : Crecto::Repo::Query)
      raise InvalidOption.new("Aggregate must be one of :avg, :count, :max, :min:, :sum") unless [:avg, :count, :max, :min, :sum].includes?(aggregate_function)

      config.adapter.aggregate(config.get_connection, queryable, aggregate_function, field, query)
    end

    private def check_dependents(changeset, tx : DB::Transaction?) : Nil
      return if changeset.instance.class.destroy_associations.empty? && changeset.instance.class.nilify_associations.empty?
      # delete
      changeset.instance.class.destroy_associations.each do |destroy_assoc|
        q = Crecto::Repo::Query.where(changeset.instance.class.foreign_key_for_association(destroy_assoc), changeset.instance.pkey_value)
        delete_all(changeset.instance.class.klass_for_association(destroy_assoc), q, tx)
      end

      # nilify
      changeset.instance.class.nilify_associations.each do |nilify_assoc|
        foreign_key = changeset.instance.class.foreign_key_for_association(nilify_assoc)
        q = Crecto::Repo::Query.where(foreign_key, changeset.instance.pkey_value)
        update_all(changeset.instance.class.klass_for_association(nilify_assoc), q, { foreign_key => nil}, tx)
      end
    end

    private def check_dependents(queryable, query : Query, tx : DB::Transaction?)
      return if queryable.destroy_associations.empty? && queryable.nilify_associations.empty?
      q = query
      q.select([queryable.primary_key_field])
      ids = all(queryable, q).map{|o| o.pkey_value }
      return if ids.empty?

      queryable.destroy_associations.each do |destroy_assoc|
        q = Crecto::Repo::Query.where(queryable.foreign_key_for_association(destroy_assoc), ids)
        delete_all(queryable.klass_for_association(destroy_assoc), q, tx)
      end

      queryable.nilify_associations.each do |nilify_assoc|
        foreign_key = queryable.foreign_key_for_association(nilify_assoc)
        q = Crecto::Repo::Query.where(foreign_key, ids)
        update_all(queryable.klass_for_association(nilify_assoc), q, { foreign_key => nil }, tx)
      end
    end

    private def add_preloads(results, queryable, preloads)
      preloads.each do |preload|
        case queryable.association_type_for_association(preload)
        when :has_many
          has_many_preload(results, queryable, preload)
        when :has_one
          has_one_preload(results, queryable, preload)
        when :belongs_to
          belongs_to_preload(results, queryable, preload)
        end
      end
    end

    private def has_one_preload(results, queryable, preload)
      query = Crecto::Repo::Query.where(queryable.foreign_key_for_association(preload), results[0].pkey_value)
      relation_item = all(queryable.klass_for_association(preload), query)
      unless relation_item.nil? || relation_item.empty?
        queryable.set_value_for_association(preload, results[0], relation_item[0])
      end
    end

    private def has_many_preload(results, queryable, preload)
      if queryable.through_key_for_association(preload)
        join_through(results, queryable, preload)
      else
        join_single(results, queryable, preload)
      end
    end

    private def join_single(results, queryable, preload)
      ids = results.map(&.pkey_value)
      query = Crecto::Repo::Query.where(queryable.foreign_key_for_association(preload), ids)
      relation_items = all(queryable.klass_for_association(preload), query)
      unless relation_items.nil?
        relation_items = relation_items.group_by { |t| queryable.foreign_key_value_for_association(preload, t) }

        results.each do |result|
          if relation_items.has_key?(result.pkey_value)
            items = relation_items[result.pkey_value]
            queryable.set_value_for_association(preload, result, items.map { |i| i.as(Crecto::Model) })
          end
        end
      end
    end

    private def join_through(results, queryable, preload)
      ids = results.map(&.pkey_value)
      join_query = Crecto::Repo::Query.where(queryable.foreign_key_for_association(preload), ids)
      # UserProjects
      join_table_items = all(queryable.klass_for_association(queryable.through_key_for_association(preload).as(Symbol)), join_query)
      unless join_table_items.nil? || join_table_items.empty?
        # array of Project id's
        join_ids = join_table_items.map { |i| queryable.klass_for_association(preload).foreign_key_value_for_association(queryable.through_key_for_association(preload).as(Symbol), i) }
        association_query = Crecto::Repo::Query.where(queryable.klass_for_association(preload).primary_key_field_symbol, join_ids)
        # Projects
        relation_items = all(queryable.klass_for_association(preload), association_query)

        # UserProject grouped by user_id
        join_table_items = join_table_items.group_by { |t| queryable.foreign_key_value_for_association(queryable.through_key_for_association(preload).as(Symbol), t) }

        results.each do |result|
          if join_table_items.has_key?(result.pkey_value)
            join_items = join_table_items[result.pkey_value]

            # set join table has_many assocation i.e. user.user_projects
            queryable.set_value_for_association(queryable.through_key_for_association(preload).as(Symbol), result, join_items.map { |i| i.as(Crecto::Model) })

            unless relation_items.nil?
              queryable_relation_items = relation_items.select { |i| join_ids.includes?(i.pkey_value) }

              # set association i.e. user.projects
              queryable.set_value_for_association(preload, result, queryable_relation_items.map { |i| i.as(Crecto::Model) })
            end
          end
        end
      end
    end

    private def belongs_to_preload(results, queryable, preload)
      ids = results.map { |r| queryable.foreign_key_value_for_association(preload, r) }
      return if ids.empty?
      query = Crecto::Repo::Query.where(id: ids)
      relation_items = all(queryable.klass_for_association(preload), query)

      unless relation_items.nil?
        relation_items = relation_items.group_by { |t| t.pkey_value }

        results.each do |result|
          fkey = queryable.foreign_key_value_for_association(preload, result)
          if relation_items.has_key?(fkey)
            items = relation_items[fkey]
            queryable.set_value_for_association(preload, result, items.map { |i| i.as(Crecto::Model) })
          end
        end
      end
    end

    macro extended
      @@config = Crecto::Repo::Config.new
    end

    def config
      yield @@config
    end

    def config
      @@config
    end

    class Config
      property database, username, password, hostname, port,
        initial_pool_size, max_pool_size, max_idle_pool_size, checkout_timeout, retry_attempts, retry_delay,
        adapter : Crecto::Adapters::Postgres.class | Crecto::Adapters::Mysql.class | Crecto::Adapters::SQLite3.class,
        crecto_db : DB::Database?

      def initialize
        @adapter = Crecto::Adapters::Postgres
        @database = ""
        @username = ""
        @password = ""
        @hostname = ""
        @initial_pool_size = 1
        @max_pool_size = 0
        @max_idle_pool_size = 1
        @checkout_timeout = 5.0
        @retry_attempts = 1
        @retry_delay = 1.0

        @port = 5432
      end

      def database_url
        String.build do |io|
          set_url_protocol(io)
          set_url_creds(io)
          set_url_host(io)
          set_url_port(io)
          set_url_db(io)
        end
      end

      def get_connection
        if crecto_db.nil?
          crecto_db = DB.open(database_url)
        end
        crecto_db.as(DB::Database)
      end

      private def set_url_db(io)
        if adapter == Crecto::Adapters::SQLite3
          io << "#{database}"
        else
          io << "/#{database}"
        end
      end

      private def set_url_port(io)
        return if adapter == Crecto::Adapters::SQLite3
        io << ":#{port}"
      end

      private def set_url_host(io)
        return if adapter == Crecto::Adapters::SQLite3
        io << hostname
      end

      private def set_url_creds(io)
        return if adapter == Crecto::Adapters::SQLite3
        io << URI.escape(username) unless username.empty?
        io << ":#{URI.escape(password)}" unless password.empty?
        io << "@" unless username.empty?
      end

      private def set_url_protocol(io)
        if adapter == Crecto::Adapters::Postgres
          io << "postgres://"
        elsif adapter == Crecto::Adapters::Mysql
          io << "mysql://"
        elsif adapter == Crecto::Adapters::SQLite3
          io << "sqlite3://"
        end
      end
    end
  end
end
