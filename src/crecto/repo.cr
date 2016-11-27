module Crecto
  # A repository maps to an underlying data store, controlled by the adapter.
  module Repo
    # Return a list of `queryable` instances using the *query* param
    #
    # ```
    # query = Query.where(name: "fred")
    # users = Repo.all(User, query)
    # ```
    def self.all(queryable, query = Query.new)
      Crecto::Adapters::Postgres.execute(:all, queryable, query)
    end 

    # Return a single insance of `queryable` by primary key with *id*.
    #
    # ```
    # user = Repo.get(User, 1)
    # ```
    def self.get(queryable, id)
      Crecto::Adapters::Postgres.execute(:get, queryable, id)
    end

    # Return a single instance of `queryable` using the *query* param
    #
    # ```
    # user = Repo.get_by(User, name: "fred", age: 21)
    # ```
    def self.get_by(queryable, **opts)
      Crecto::Adapters::Postgres.execute(:all, queryable, Query.where(**opts).limit(1)).as(Array)[0]
    end

    # Insert a schema instance into the data store.
    #
    # ```
    # user = User.new
    # Repo.insert(user)
    # ```
    def self.insert(queryable_instance)
      Crecto::Adapters::Postgres.execute_on_instance(:insert, queryable_instance)
    end

    # Insert a changeset instance into the data store.
    #
    # ```
    # user = User.new
    # changeset = User.changeset(user)
    # Repo.insert(changeset)
    # ```
    def self.insert(changeset : Crecto::Changeset::Changeset)
      Crecto::Adapters::Postgres.execute_on_instance(:insert, changeset)
    end


    # Update a shema instance in the data store.
    #
    # ```
    # Repo.update(user)
    # ```
    def self.update(queryable_instance)
      Crecto::Adapters::Postgres.execute_on_instance(:update, queryable_instance)
    end

    # Update a changeset instance in the data store.
    #
    # ```
    # Repo.update(changeset)
    # ```
    def self.update(changeset : Crecto::Changeset::Changeset)
      Crecto::Adapters::Postgres.execute_on_instance(:update, changeset)
    end

    # Delete a shema instance from the data store.
    #
    # ```
    # Repo.delete(user)
    # ```
    def self.delete(queryable_instance)
      Crecto::Adapters::Postgres.execute_on_instance(:delete, queryable_instance)
    end

    # Delete a changeset instance from the data store.
    #
    # ```
    # Repo.delete(changeset)
    # ```
    def self.delete(changeset : Crecto::Changeset::Changeset)
      Crecto::Adapters::Postgres.execute_on_instance(:delete, changeset)
    end

    # Not done yet, placeohlder for associations
    def self.preload
    end

    # Not done yet, placeohlder for associations
    def self.load
    end
  end
end