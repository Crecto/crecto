module Crecto
  module Repo
    def self.all(queryable, query = Query.new)
      Crecto::Adapters::Postgres.execute(:all, queryable, query)
    end

    def self.get(queryable, id)
      Crecto::Adapters::Postgres.execute(:get, queryable, id)
    end

    def self.get_by(queryable, **opts)
      Crecto::Adapters::Postgres.execute(:all, queryable, Query.where(**opts).limit(1)).as(Array)[0]
    end

    def self.insert(queryable_instance)
      Crecto::Adapters::Postgres.execute_on_instance(:insert, queryable_instance)
    end

    def self.update(queryable_instance)
      Crecto::Adapters::Postgres.execute_on_instance(:update, queryable_instance)
    end

    def self.delete
    end

    def self.preload
    end

    def self.load
    end
  end
end