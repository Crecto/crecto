module Crecto
  # A repository maps to an underlying data store, controlled by the adapter.
  module Repo
    # Return a list of `queryable` instances using the *query* param
    #
    # ```
    # query = Query.where(name: "fred")
    # users = Repo.all(User, query)
    # ```
    def self.all(queryable, query : Query = Query.new, **opts)
      q = Crecto::Adapters::Postgres.run(:all, queryable, query)
      q.to_hash.map{|row| queryable.from_sql(row) } unless q.nil?
    end

    macro assoc(queryable_instance, association)
      q = Crecto::Adapters::Postgres.run(:all, {{queryable_instance.id}}.class_for_association_{{association.id}}, Crecto::Repo::Query.where({{queryable_instance.id}}.foreign_key_for_association_{{association.id}}, {{queryable_instance}}.value_for_association_{{association.id}}))
      unless q.nil?
        {{association.id}} = q.to_hash.map{|row| {{queryable_instance.id}}.class_for_association_{{association.id}}.from_sql(row) }
        {{queryable_instance}}.{{association.id}} = {{association.id}}
      end
    end

    # Return a single insance of `queryable` by primary key with *id*.
    #
    # ```
    # user = Repo.get(User, 1)
    # ```
    def self.get(queryable, id)
      query = Crecto::Adapters::Postgres.run(:get, queryable, id)
      queryable.from_sql(query.to_hash[0]) unless query.nil? || query.rows.size == 0
    end

    # Return a single instance of `queryable` using the *query* param
    #
    # ```
    # user = Repo.get_by(User, name: "fred", age: 21)
    # ```
    def self.get_by(queryable, **opts)
      query = Crecto::Adapters::Postgres.run(:all, queryable, Query.where(**opts).limit(1))
      queryable.from_sql(query.to_hash[0]) unless query.nil? || query.rows.size == 0
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

      query = Crecto::Adapters::Postgres.run_on_instance(:insert, changeset)

      if query.nil?
        changeset.add_error("insert_error", "Insert Failed")
      else
        new_instance = changeset.instance.class.from_sql(query.to_hash[0])
        changeset = new_instance.class.changeset(new_instance) unless new_instance.nil?
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

      query = Crecto::Adapters::Postgres.run_on_instance(:update, changeset)

      if query.nil?
        changeset.add_error("update_error", "Update Failed")
      else
        new_instance = changeset.instance.class.from_sql(query.to_hash[0])
        changeset = new_instance.class.changeset(new_instance) unless new_instance.nil?
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
    def self.update_all(queryable, query, update_hash)
      query = Crecto::Adapters::Postgres.run(:update_all, queryable, query, update_hash)
    end

    # Delete a shema instance from the data store.
    #
    # ```
    # Repo.delete(user)
    # ```
    def self.delete(queryable_instance)
      changeset = queryable_instance.class.changeset(queryable_instance)
      return changeset unless changeset.valid?

      query = Crecto::Adapters::Postgres.run_on_instance(:delete, changeset)

      if query.nil?
        changeset.add_error("delete_error", "Delete Failed")
      else
        new_instance = changeset.instance.class.from_sql(query.to_hash[0])
        changeset = new_instance.class.changeset(new_instance) unless new_instance.nil?
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
      query = Crecto::Adapters::Postgres.run(:delete_all, queryable, query)
    end

    # Not done yet, placeohlder for associations
    def self.preload
    end

    # Not done yet, placeohlder for associations
    def self.load
    end
  end
end
