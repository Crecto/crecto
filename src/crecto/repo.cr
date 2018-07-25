module Crecto
  # A repository maps to an underlying data store, controlled by the adapter.
  module Repo
    class OperationError < Exception
      def initialize(error : Exception, @queryable : Model.class, @failed_operation : String)
        super(error.message)
      end

      def to_h
        {
          :message          => @message.to_s,
          :queryable        => @queryable.to_s,
          :failed_operation => @failed_operation,
        }
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

    # Run a raw `exec` query directly on the adapter connection
    def raw_exec(args : Array)
      config.get_connection.exec(args)
    end

    # Run a raw `exec` query directly on the adapter connection
    def raw_exec(*args)
      config.get_connection.exec(*args)
    end

    # Run a raw `query` query directly on the adapter connection
    def raw_query(query, *args)
      config.get_connection.query(query, *args) do |rs|
        yield rs
      end
    end

    # Run a raw `query` query directly on the adapter connection
    def raw_query(query, args : Array)
      config.get_connection.query(args)
    end

    # Run a raw `query` query directly on the adapter connection
    def raw_query(query, *args)
      config.get_connection.query(*args)
    end

    # Run a raw `scalar` query directly on the adapter connection
    def raw_scalar(*args)
      config.get_connection.scalar(*args)
    end

    # Return a list of *queryable* instances using *query*
    #
    # ```
    # query = Query.where(name: "fred")
    # users = Repo.all(User, query)
    # ```
    def all(queryable, query : Query? = Query.new, **opts) : Array
      q = config.adapter.run(config.get_connection, :all, queryable, query).as(DB::ResultSet)

      results = queryable.from_rs(q.as(DB::ResultSet))

      opt_preloads = opts.fetch(:preload, [] of Symbol)
      preloads = query.preloads + opt_preloads.map{|a| {symbol: a, query: nil}}
      if preloads.any?
        add_preloads(results, queryable, preloads)
      end

      results
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
      if result = get(queryable, id, query)
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

    # Return the value of the given association on *queryable_instance*
    #
    # ```
    # user = Crecto::Repo.get(User, 1)
    # post = Repo.get_association(user, :post)
    # ```
    def get_association(queryable_instance, association_name : Symbol)
      case queryable_instance.class.association_type_for_association(association_name)
      when :has_many
        get_has_many_association(queryable_instance, association_name)
      when :has_one
        get_has_one_association(queryable_instance, association_name)
      when :belongs_to
        get_belongs_to_association(queryable_instance, association_name)
      end
    end

    # Return the value of the given association on *queryable_instance*
    # Raises `NoResults` error if association has no value. Will not raise
    # for `has_many` associations.
    #
    # ```
    # user = Crecto::Repo.get(User, 1)
    # post = Repo.get_association!(user, :post)
    # ```
    def get_association!(queryable_instance, association_name : Symbol)
      if result = get_association(queryable_instance, association_name)
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

      begin
        changeset.instance.updated_at_to_now
        changeset.instance.created_at_to_now

        query = config.adapter.run_on_instance(tx || config.get_connection, :insert, changeset)

        if query.nil?
          changeset.add_error("insert_error", "Insert Failed")
        elsif config.adapter == Crecto::Adapters::Postgres || (config.adapter == Crecto::Adapters::Mysql && tx.nil?) ||
              (config.adapter == Crecto::Adapters::SQLite3 && tx.nil?)
          if query.is_a?(DB::ResultSet)
            new_instance = changeset.instance.class.from_rs(query.as(DB::ResultSet)).first?
            changeset = new_instance.class.changeset(new_instance) if new_instance
          else
            changeset = queryable_instance.class.changeset(queryable_instance)
          end
        end
      rescue e
        raise e unless changeset.check_unique_constraint_from_exception!(e, queryable_instance)
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

      begin
        changeset.instance.updated_at_to_now

        query = config.adapter.run_on_instance(tx || config.get_connection, :update, changeset)

        if query.nil?
          changeset.add_error("update_error", "Update Failed")
        else
          new_instance = changeset.instance.class.from_rs(query.as(DB::ResultSet)).first?
          changeset = new_instance.class.changeset(new_instance) if new_instance
        end
      rescue e
        raise e unless changeset.check_unique_constraint_from_exception!(e, queryable_instance)
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
      elsif tx.nil? && config.adapter == Crecto::Adapters::Postgres # patch for bug in crystal-pg
        query.as(DB::ResultSet).close
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
      result = config.adapter.run(tx || config.get_connection, :delete_all, queryable, query)
      if tx.nil? && config.adapter == Crecto::Adapters::Postgres
        result.as(DB::ResultSet).close if result.is_a?(DB::ResultSet)
      end
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
    # Please note that you have to close the result set yourself, otherwise there will be staled connections!
    #
    # ```
    # query = Crecto::Repo.query("select * from users where id = ?", [30])
    # ```
    def query(sql : String, params = [] of DbValue) : DB::ResultSet
      config.adapter.run(config.get_connection, :sql, sql, params).as(DB::ResultSet)
    end

    def transaction(multi : Crecto::Multi)
      return multi unless multi.changesets_valid?

      config.get_connection.transaction do |tx|
        begin
          multi.operations.each do |operation|
            run_operation(operation, tx)
          end
        rescue error : OperationError
          multi.errors = [error.to_h]
          tx.rollback
        end
      end

      multi
    end

    {% for operation in %w[insert update delete] %}
      private def run_operation(operation : Multi::{{operation.camelcase.id}}, tx)
        {{operation.id}}(operation.instance, tx)
      rescue ex : Exception
        raise OperationError.new(ex, operation.instance.class, {{operation}})
      end
    {% end %}

    private def run_operation(operation : Multi::UpdateAll, tx)
      update_all(operation.queryable, operation.query, operation.update_hash, tx)
    rescue ex : Exception
      raise OperationError.new(ex, operation.queryable, "update_all")
    end

    private def run_operation(operation : Multi::DeleteAll, tx)
      delete_all(operation.queryable, operation.query, tx)
    rescue ex : Exception
      raise OperationError.new(ex, operation.queryable, "delete_all")
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
      return if changeset.instance.class.destroy_associations.empty? && changeset.instance.class.nullify_associations.empty?
      # delete
      changeset.instance.class.destroy_associations.each do |destroy_assoc|
        delete_dependents(changeset.instance.class, destroy_assoc, changeset.instance.pkey_value, tx)
      end

      # nullify
      changeset.instance.class.nullify_associations.each do |nullify_assoc|
        nullify_dependents(changeset.instance.class, nullify_assoc, changeset.instance.pkey_value, tx)
      end
    end

    private def check_dependents(queryable, query : Query, tx : DB::Transaction?)
      return if queryable.destroy_associations.empty? && queryable.nullify_associations.empty?
      q = query
      q.select([queryable.primary_key_field])
      ids = all(queryable, q).map { |o| o.pkey_value.as(PkeyValue) }
      return if ids.empty?

      queryable.destroy_associations.each do |destroy_assoc|
        delete_dependents(queryable, destroy_assoc, ids, tx)
      end

      queryable.nullify_associations.each do |nullify_assoc|
        nullify_dependents(queryable, nullify_assoc, ids, tx)
      end
    end

    private def delete_dependents(queryable, destroy_assoc, ids, tx)
      through_key = queryable.through_key_for_association(destroy_assoc)
      if through_key.nil?
        q = Crecto::Repo::Query.where(queryable.foreign_key_for_association(destroy_assoc), ids)
        delete_all(queryable.klass_for_association(destroy_assoc), q, tx)
      else
        outer_klass = queryable.klass_for_association(destroy_assoc) # Project
        join_klass = queryable.klass_for_association(through_key)    # UserProject
        query = Query.select([join_klass.foreign_key_for_association(outer_klass).to_s])
        query = query.where(queryable.foreign_key_for_association(destroy_assoc), ids)
        join_associations = all(join_klass, query)
        outer_klass_ids = join_associations.map { |ja| outer_klass.foreign_key_value_for_association(through_key, ja) }
        join_klass_ids = join_associations.map { |ja| ja.pkey_value.as(PkeyValue) }
        delete_all(join_klass, Query.where(queryable.foreign_key_for_association(through_key), ids), tx) unless join_klass_ids.empty?
        delete_all(outer_klass, Query.where(:id, outer_klass_ids), tx) unless outer_klass_ids.empty?
      end
    end

    private def nullify_dependents(queryable, nullify_assoc, ids, tx)
      through_key = queryable.through_key_for_association(nullify_assoc)
      if through_key.nil?
        foreign_key = queryable.foreign_key_for_association(nullify_assoc)
        q = Crecto::Repo::Query.where(foreign_key, ids)
        update_all(queryable.klass_for_association(nullify_assoc), q, {foreign_key => nil}, tx)
      end
    end

    private def add_preloads(results, queryable, preloads)
      preloads.each do |preload|
        case queryable.association_type_for_association(preload[:symbol])
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
      query = Crecto::Repo::Query.where(queryable.foreign_key_for_association(preload[:symbol]), results[0].pkey_value)
      if preload_query = preload[:query]
        query = query.combine(preload_query)
      end
      relation_item = all(queryable.klass_for_association(preload[:symbol]), query)
      if relation_item.first?
        queryable.set_value_for_association(preload[:symbol], results[0], relation_item.first)
      end
    end

    private def has_many_preload(results, queryable, preload)
      if queryable.through_key_for_association(preload[:symbol])
        join_through(results, queryable, preload)
      else
        join_direct(results, queryable, preload)
      end
    end

    private def join_direct(results, queryable, preload)
      ids = results.map(&.pkey_value.as(PkeyValue))
      query = Crecto::Repo::Query.where(queryable.foreign_key_for_association(preload[:symbol]), ids)
      if preload_query = preload[:query]
        query = query.combine(preload_query)
      end
      relation_items = all(queryable.klass_for_association(preload[:symbol]), query)
      relation_items = relation_items.group_by { |t| queryable.foreign_key_value_for_association(preload[:symbol], t) }

      results.each do |result|
        items = relation_items[result.pkey_value]? || [] of Crecto::Model
        queryable.set_value_for_association(preload[:symbol], result, items.map { |i| i.as(Crecto::Model) })
      end
    end

    private def join_through(results, queryable, preload)
      ids = results.map(&.pkey_value.as(PkeyValue))
      join_query = Crecto::Repo::Query.where(queryable.foreign_key_for_association(preload[:symbol]), ids)
      # UserProjects
      join_table_items = all(queryable.klass_for_association(queryable.through_key_for_association(preload[:symbol]).as(Symbol)), join_query)

      # array of Project id's
      if join_table_items.empty?
        # Set default association values as empty arrays to avoid confusion
        # between empty results and non-loaded associations.
        results.each do |result|
          queryable.set_value_for_association(queryable.through_key_for_association(preload[:symbol]).as(Symbol), result, [] of Crecto::Model)
          queryable.set_value_for_association(preload[:symbol], result, [] of Crecto::Model)
        end
      else
        join_ids = join_table_items.map { |i| queryable.klass_for_association(preload[:symbol]).foreign_key_value_for_association(queryable.through_key_for_association(preload[:symbol]).as(Symbol), i) }
        association_query = Crecto::Repo::Query.where(queryable.klass_for_association(preload[:symbol]).primary_key_field_symbol, join_ids)
        if preload_query = preload[:query]
          association_query = association_query.combine(preload_query)
        end
        # Projects
        relation_items = all(queryable.klass_for_association(preload[:symbol]), association_query)
        # UserProject grouped by user_id
        join_table_items = join_table_items.group_by { |t| queryable.foreign_key_value_for_association(queryable.through_key_for_association(preload[:symbol]).as(Symbol), t) }

        results.each do |result|
          join_items = join_table_items[result.pkey_value]? || [] of Crecto::Model
          # set join table has_many assocation i.e. user.user_projects
          queryable.set_value_for_association(queryable.through_key_for_association(preload[:symbol]).as(Symbol), result, join_items.map { |i| i.as(Crecto::Model) })
          queryable_relation_items = relation_items.select { |i| join_ids.includes?(i.pkey_value) }
          # set association i.e. user.projects
          queryable.set_value_for_association(preload[:symbol], result, queryable_relation_items.map { |i| i.as(Crecto::Model) })
        end
      end
    end

    private def belongs_to_preload(results, queryable, preload)
      ids = results.map { |r| queryable.foreign_key_value_for_association(preload[:symbol], r) }
      return if ids.empty?
      query = Crecto::Repo::Query.where(id: ids)
      if preload_query = preload[:query]
        query = query.combine(preload_query)
      end
      relation_items = all(queryable.klass_for_association(preload[:symbol]), query)

      unless relation_items.nil?
        relation_items = relation_items.group_by { |t| t.pkey_value.as(PkeyValue) }

        results.each do |result|
          fkey = queryable.foreign_key_value_for_association(preload[:symbol], result)
          if relation_items.has_key?(fkey)
            items = relation_items[fkey]
            queryable.set_value_for_association(preload[:symbol], result, items.map { |i| i.as(Crecto::Model) })
          end
        end
      end
    end

    private def get_has_many_association(instance, association : Symbol)
      queryable = instance.class
      query = Crecto::Repo::Query.where(queryable.foreign_key_for_association(association), instance.pkey_value)
      all(queryable.klass_for_association(association), query)
    end

    private def get_has_one_association(instance, association : Symbol)
      get_has_many_association(instance, association).first?
    end

    private def get_belongs_to_association(instance, association : Symbol)
      queryable = instance.class
      klass_for_association = queryable.klass_for_association(association)
      key_for_association = queryable.foreign_key_value_for_association(association, instance)
      get(klass_for_association, key_for_association)
    end
  end
end
