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
  end
end
