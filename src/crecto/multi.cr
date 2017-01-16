module Crecto
  # Multi is used for grouping multiple Repo operations into a single transaction
  #
  # Operations will be executed in the order they were added
  #
  # If a Multi contains operations that accept a Changeset, they will be checked before starting the transaction.
  # If any changesets have errors, the transaction will never be started.
  #
  alias OpType = Crecto::Model | Crecto::Changeset::Changeset(Crecto::Model)

  class Multi
    property sortorder = 1
    property changeset_inserts = Array(NamedTuple(sortorder: Int32, changeset: Crecto::Changeset::Changeset(Crecto::Model))).new
    property changeset_deletes = Array(NamedTuple(sortorder: Int32, changeset: Crecto::Changeset::Changeset(Crecto::Model))).new
    property delete_alls = Array(NamedTuple(sortorder: Int32, queryable: Crecto::Model.class, query: Crecto::Repo::Query)).new
    property changeset_updates = Array(NamedTuple(sortorder: Int32, changeset: Crecto::Changeset::Changeset(Crecto::Model))).new
    property update_alls = Array(NamedTuple(sortorder: Int32, queryable: Crecto::Model.class, query: Crecto::Repo::Query, update_hash: Hash(Symbol, DbValue))).new

    def insert(queryable_instance : Crecto::Model)
      changeset = queryable_instance.class.changeset(queryable_instance)
      insert(changeset)
    end

    def insert(changeset : Crecto::Changeset::Changeset)
      changeset_inserts.push({sortorder: @sortorder += 1, changeset: changeset})
    end

    def delete(queryable_instance : Crecto::Model)
      changeset = queryable_instance.class.changeset(queryable_instance)
      delete(changeset)
    end

    def delete(changeset : Crecto::Changeset::Changeset)
      changeset_deletes.push({sortorder: @sortorder += 1, changeset: changeset})
    end

    def delete_all(queryabe, query = Query.new)
      delete_alls.push({sortorder: @sortorder += 1, queryable: queryable, query: query})
    end

    def update(queryable_instance : Crecto::Model)
      changeset = queryable_instance.class.changeset(queryable_instance)
      update(changeset)
    end

    def update(changeset : Crecto::Changeset::Changeset)
      changeset_updates.push({sortorder: @sortorder += 1, changeset: changeset})
    end

    def update_all(queryable, query, update_hash : Hash)
      update_alls.push({sortorder: @sortorder += 1, queryable: queryable, query: query, update_hash: update_hash})
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end
  end
end
