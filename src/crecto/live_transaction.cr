require "./repo/query"

module Crecto
  class LiveTransaction(T)
    alias Query = Repo::Query

    def initialize(@tx : DB::Transaction, @repo : T)
    end

    def raw_exec(args : Array)
      @repo.raw_exec(args, tx: @tx)
    end

    def raw_exec(*args)
      @repo.raw_exec(*args, tx: @tx)
    end

    def raw_query(query, *args)
      @repo.raw_query(query, *args, tx: @tx) do |rs|
        yield rs
      end
    end

    def raw_query(query, args : Array)
      @repo.raw_query(query, args, tx: @tx)
    end

    def raw_query(query, *args)
      @repo.raw_query(query, *args)
    end

    def raw_scalar(*args)
      @repo.raw_scalar(*args, tx: @tx)
    end

    def all(queryable, query : Query, *, preload = [] of Symbol)
      @repo.all(queryable, query, tx: @tx, preload: preload)
    end

    def all(queryable, query = Query.new)
      @repo.all(queryable, query, tx: @tx)
    end

    def get(queryable, id)
      @repo.get(queryable, id, tx: @tx)
    end

    def get!(queryable, id)
      @repo.get!(queryable, id, tx: @tx)
    end

    def get(queryable, id, query : Query)
      @repo.get(queryable, id, query, tx: @tx)
    end

    def get!(queryable, id, query : Query)
      @repo.get!(queryable, id, query, tx: @tx)
    end

    def get_by(queryable, **opts)
      @repo.get_by(queryable, @tx, **opts)
    end

    def get_by(queryable, query)
      @repo.get_by(queryable, query, tx: @tx)
    end

    def get_by!(queryable, **opts)
      @repo.get_by!(queryable, @tx, **opts)
    end

    def get_by!(queryable, query)
      @repo.get_by!(queryable, query, tx: @tx)
    end

    def get_association(queryable_instance, association_name : Symbol)
      @repo.get_association(queryable_instance, association_name, tx: @tx)
    end

    def get_association!(queryable_instance, association_name : Symbol)
      @repo.get_association!(queryable_instance, association_name, tx: @tx)
    end

    {% for type in %w[insert insert! delete delete! update update!] %}
      def {{type.id}}(queryable : Crecto::Model)
        @repo.{{type.id}}(queryable, tx: @tx)
      end

      def {{type.id}}(changeset : Crecto::Changeset::Changeset)
        {{type.id}}(changeset.instance)
      end
    {% end %}

    def delete_all(queryable, query = Crecto::Repo::Query.new)
      @repo.delete_all(queryable, query, tx: @tx)
    end

    def update_all(queryable, query, update_hash : Multi::UpdateHash)
      @repo.update_all(queryable, query, update_hash, tx: @tx)
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end

    def aggregate(queryable, aggregate_function : Symbol, field : Symbol)
      @repo.aggregate(queryable, aggregate_function, field, tx: @tx)
    end

    def aggregate(queryable, aggregate_function : Symbol, field : Symbol, query : Crecto::Repo::Query)
      @repo.aggregate(queryable, aggregate_function, field, query, tx: @tx)
    end

    def transaction!
      @repo.transaction!(@tx) do |tx|
        yield tx
      end
    end
  end
end
