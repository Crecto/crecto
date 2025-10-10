require "./multi"

module Crecto
  class LiveTransaction(T)
    def initialize(@tx : DB::Transaction, @repo : T)
    end

    {% for type in %w[insert insert! delete delete! update update!] %}
      def {{type.id}}(queryable : Crecto::Model)
        @repo.{{type.id}}(queryable, @tx)
      end

      def {{type.id}}(changeset : Crecto::Changeset::Changeset)
        {{type.id}}(changeset.instance)
      end
    {% end %}

    def delete_all(queryable, query = Crecto::Repo::Query.new)
      @repo.delete_all(queryable, query, @tx)
    end

    def update_all(queryable, query, update_hash : Multi::UpdateHash)
      @repo.update_all(queryable, query, update_hash, @tx)
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end

    def get(queryable, id)
      @repo.get(queryable, id, @tx)
    end

    def get!(queryable, id)
      if result = get(queryable, id)
        result
      else
        raise NoResults.new("No Results")
      end
    end

    def get_by(queryable, **opts)
      @repo.get_by(queryable, **opts)
    end

    def get_by!(queryable, **opts)
      @repo.get_by!(queryable, **opts)
    end

    def all(queryable, query = Crecto::Repo::Query.new)
      # Use a simple implementation that queries through the transaction
      # For now, we'll delegate to the repo's all method but note that
      # it won't use the transaction connection for complex queries
      @repo.all(queryable, query)
    end
  end

  # NestedTransaction provides savepoint-based nested transaction support
  class NestedTransaction(T)
    def initialize(@connection : DB::Database, @repo : T, @savepoint_name : String)
    end

    {% for type in %w[insert insert! delete delete! update update!] %}
      def {{type.id}}(queryable : Crecto::Model)
        @repo.{{type.id}}(queryable, nil) # Pass nil for transaction since we're using savepoints
      end

      def {{type.id}}(changeset : Crecto::Changeset::Changeset)
        {{type.id}}(changeset.instance)
      end
    {% end %}

    def delete_all(queryable, query = Crecto::Repo::Query.new)
      @repo.delete_all(queryable, query, nil)
    end

    def update_all(queryable, query, update_hash : Multi::UpdateHash)
      @repo.update_all(queryable, query, update_hash, nil)
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end

    # Rollback to the savepoint for this nested transaction
    def rollback
      if @connection.responds_to?(:exec) && @savepoint_name
        @connection.exec("ROLLBACK TO SAVEPOINT #{@savepoint_name}")
      end
    end
  end
end
