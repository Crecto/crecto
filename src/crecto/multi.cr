module Crecto
  # Multi is used for grouping multiple Repo operations into a single transaction
  #
  # Operations will be executed in the order they were added
  #
  # If a Multi contains operations that accept a Changeset, they will be checked before starting the transaction.
  # If any changesets have errors, the transaction will never be started.
  #
  class Multi
    property sortorder = 0
    property errors : Array(Hash(Symbol, String))?
    property inserts = Array(NamedTuple(sortorder: Int32, instance: Crecto::Model)).new
    property deletes = Array(NamedTuple(sortorder: Int32, instance: Crecto::Model)).new
    property delete_alls = Array(NamedTuple(sortorder: Int32, queryable: Crecto::Model.class, query: Crecto::Repo::Query)).new
    property updates = Array(NamedTuple(sortorder: Int32, instance: Crecto::Model)).new
    property update_alls = Array(NamedTuple(sortorder: Int32, queryable: Crecto::Model.class, query: Crecto::Repo::Query, update_hash: Hash(Symbol, PkeyValue) | Hash(Symbol, DbValue) | Hash(Symbol, Array(DbValue)) | Hash(Symbol, Array(PkeyValue)) | Hash(Symbol, Array(Int32)) | Hash(Symbol, Array(Int64)) | Hash(Symbol, Array(String)) | Hash(Symbol, Int32 | String) | Hash(Symbol, Int32) | Hash(Symbol, Int64) | Hash(Symbol, String) | Hash(Symbol, Int32 | Int64 | String | Nil))).new

    def insert(queryable_instance : Crecto::Model)
      @inserts.push({sortorder: @sortorder += 1, instance: queryable_instance})
    end

    def insert(changeset : Crecto::Changeset::Changeset)
      insert(changeset.instance)
    end

    def delete(queryable_instance : Crecto::Model)
      @deletes.push({sortorder: @sortorder += 1, instance: queryable_instance})
    end

    def delete(changeset : Crecto::Changeset::Changeset)
      delete(changeset.instance)
    end

    def delete_all(queryable, query = Crecto::Repo::Query.new)
      @delete_alls.push({sortorder: @sortorder += 1, queryable: queryable, query: query})
    end

    def update(queryable_instance : Crecto::Model)
      @updates.push({sortorder: @sortorder += 1, instance: queryable_instance})
    end

    def update(changeset : Crecto::Changeset::Changeset)
      update(changeset.instance)
    end

    def update_all(queryable, query, update_hash : Hash)
      @update_alls.push({sortorder: @sortorder += 1, queryable: queryable, query: query, update_hash: update_hash})
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end

    def changesets_valid?
      @inserts.each do |i|
        changeset = i[:instance].get_changeset
        unless changeset.valid?
          @errors = changeset.errors
          @errors.not_nil![0][:queryable] = i[:instance].class.to_s
          @errors.not_nil![0][:failed_operation] = "insert"
          return false
        end
      end

      @deletes.each do |d|
        changeset = d[:instance].get_changeset
        unless changeset.valid?
          @errors = changeset.errors
          @errors.not_nil![0][:queryable] = d[:instance].class.to_s
          @errors.not_nil![0][:failed_operation] = "insert"
          return false
        end
      end

      @updates.each do |u|
        changeset = u[:instance].get_changeset
        unless changeset.valid?
          @errors = changeset.errors
          @errors.not_nil![0][:queryable] = u[:instance].class.to_s
          @errors.not_nil![0][:failed_operation] = "insert"
          return false
        end
      end

      return true
    end
  end
end
