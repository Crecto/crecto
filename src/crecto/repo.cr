module Crecto
  # A repository maps to an underlying data store, controlled by the adapter.
  module Repo
    # Set Adapter

    # :nodoc:
    ADAPTER = if DB.drivers.keys.includes?("mysql")
                Crecto::Adapters::Mysql
              elsif DB.drivers.keys.includes?("postgres") || DB.drivers.keys.includes?("postgresql")
                Crecto::Adapters::Postgres
              else
                raise Crecto::InvalidAdapter.new("Invalid or no adapter specified")
              end

    # Return a list of *queryable* instances using *query*
    #
    # ```
    # query = Query.where(name: "fred")
    # users = Repo.all(User, query)
    # ```
    def self.all(queryable, query : Query? = Query.new, **opts)
      q = ADAPTER.run(:all, queryable, query)
      return nil if q.nil?

      results = queryable.from_rs(q.as(DB::ResultSet))
      q.as(DB::ResultSet).close

      if query.preloads.any?
        add_preloads(results, queryable, query.preloads)
      end

      results
    end

    # Return a list of *queryable* instances
    #
    # ```
    # user = Crecto::Repo.get(User, 1)
    # posts = Repo.all(user, :post)
    # ```
    def self.all(queryable_instance, association_name : Symbol)
      query = Crecto::Repo::Query.where(queryable_instance.class.foreign_key_for_association(association_name), queryable_instance.pkey_value)
      all(queryable_instance.class.klass_for_association(association_name), query)
    end

    # Returns a list of *queryable* instances.  Accepts an optional `query`
    #
    # ```
    # users = Crecto::Repo.all(User)
    # ```
    def self.all(queryable, query = Query.new)
      q = ADAPTER.run(:all, queryable, query).as(DB::ResultSet)
      results = queryable.from_rs(q)
      q.close
      results
    end

    # Return a single insance of *queryable* by primary key with *id*.
    #
    # ```
    # user = Repo.get(User, 1)
    # ```
    def self.get(queryable, id)
      q = ADAPTER.run(:get, queryable, id).as(DB::ResultSet)
      results = queryable.from_rs(q)
      q.close
      results.first if results.any?
    end

    # Return a single insance of *queryable* by primary key with *id*.
    # Can pass a Query for the purpose of preloading associations
    #
    # ```
    # query = Query.preload(:posts)
    # user = Repo.get(User, 1, query)
    # ```
    def self.get(queryable, id, query : Query)
      q = ADAPTER.run(:get, queryable, id).as(DB::ResultSet)
      results = queryable.from_rs(q)
      q.close

      if query.preloads.any?
        add_preloads(results, queryable, query.preloads)
      end

      results.first if results.any?
    end

    # Return a single instance of *queryable* using the *query* param
    #
    # ```
    # user = Repo.get_by(User, name: "fred", age: 21)
    # ```
    def self.get_by(queryable, **opts)
      q = ADAPTER.run(:all, queryable, Query.where(**opts).limit(1)).as(DB::ResultSet)
      results = queryable.from_rs(q)
      q.close
      results.first if results.any?
    end

    # Insert a schema instance into the data store.
    #
    # ```
    # user = User.new
    # Repo.insert(user)
    # ```
    def self.insert(queryable_instance)
      changeset = queryable_instance.class.changeset(queryable_instance)
      return changeset unless changeset.valid?

      changeset.instance.updated_at_to_now
      changeset.instance.created_at_to_now

      query = ADAPTER.run_on_instance(:insert, changeset)

      if query.nil?
        changeset.add_error("insert_error", "Insert Failed")
      else
        new_instance = changeset.instance.class.from_rs(query.as(DB::ResultSet)).first
        query.as(DB::ResultSet).close
        changeset = new_instance.class.changeset(new_instance) if new_instance
      end

      changeset.action = :insert
      changeset
    end

    # Insert a changeset instance into the data store.
    #
    # ```
    # user = User.new
    # changeset = User.changeset(user)
    # Repo.insert(changeset)
    # ```
    def self.insert(changeset : Crecto::Changeset::Changeset)
      insert(changeset.instance)
    end

    # Update a shema instance in the data store.
    #
    # ```
    # Repo.update(user)
    # ```
    def self.update(queryable_instance)
      changeset = queryable_instance.class.changeset(queryable_instance)
      return changeset unless changeset.valid?

      changeset.instance.updated_at_to_now

      query = ADAPTER.run_on_instance(:update, changeset)

      if query.nil?
        changeset.add_error("update_error", "Update Failed")
      else
        new_instance = changeset.instance.class.from_rs(query.as(DB::ResultSet)).first
        query.as(DB::ResultSet).close
        changeset = new_instance.class.changeset(new_instance) if new_instance
      end

      changeset.action = :update
      changeset
    end

    # Update a changeset instance in the data store.
    #
    # ```
    # Repo.update(changeset)
    # ```
    def self.update(changeset : Crecto::Changeset::Changeset)
      update(changeset.instance)
    end

    # Update multipile records with a single query
    #
    # ```
    # query = Crecto::Repo::Query.where(name: "Ted", count: 0)
    # Repo.update_all(User, query, {count: 1, date: Time.now})
    # ```
    def self.update_all(queryable, query, update_hash : Hash)
      query = ADAPTER.run(:update_all, queryable, query, update_hash)
    end

    def self.update_all(queryable, query, update_hash : NamedTuple)
      update_all(queryable, query, update_hash.to_h)
    end

    # Delete a shema instance from the data store.
    #
    # ```
    # Repo.delete(user)
    # ```
    def self.delete(queryable_instance)
      changeset = queryable_instance.class.changeset(queryable_instance)
      return changeset unless changeset.valid?

      query = ADAPTER.run_on_instance(:delete, changeset)

      if query.nil?
        changeset.add_error("delete_error", "Delete Failed")
      else
        new_instance = changeset.instance.class.from_rs(query.as(DB::ResultSet)).first
        query.as(DB::ResultSet).close
        changeset = new_instance.class.changeset(new_instance) if new_instance
      end

      changeset.action = :delete
      changeset
    end

    # Delete a changeset instance from the data store.
    #
    # ```
    # Repo.delete(changeset)
    # ```
    def self.delete(changeset : Crecto::Changeset::Changeset)
      delete(changeset.instance)
    end

    # Delete multipile records with a single query
    #
    # ```
    # query = Crecto::Repo::Query.where(name: "Fred")
    # Repo.delete_all(User, query)
    # ```
    def self.delete_all(queryable, query = Query.new)
      query = ADAPTER.run(:delete_all, queryable, query)
    end

    # Run aribtrary sql queries. `query` will cast the output as that
    # object. In this example, `query` will try to cast the
    # output as `User`. If query results happen to error nil is
    # returned
    #
    # ```
    # Repo.query(User, "select * from users where id > ?", [30])
    # ```
    def self.query(queryable, sql : String, params = [] of DbValue)
      q = ADAPTER.run(:sql, sql, params).as(DB::ResultSet)
      results = queryable.from_rs(q)
      q.close
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
    def self.query(sql : String, params = [] of DbValue)
      ADAPTER.run(:sql, sql, params)
    end

    private def self.add_preloads(results, queryable, preloads)
      preloads.each do |preload|
        case queryable.association_type_for_association(preload)
        when :has_many
          has_many_preload(results, queryable, preload)
        when :belongs_to
          belongs_to_preload(results, queryable, preload)
        end
      end
    end

    private def self.has_many_preload(results, queryable, preload)
      if queryable.through_key_for_association(preload)
        join_through(results, queryable, preload)
      else
        join_single(results, queryable, preload)
      end
    end

    private def self.join_single(results, queryable, preload)
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

    private def self.join_through(results, queryable, preload)
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

    private def self.belongs_to_preload(results, queryable, preload)
      ids = results.map { |r| queryable.foreign_key_value_for_association(preload, r) }
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
  end
end
