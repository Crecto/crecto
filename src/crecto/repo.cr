module Crecto
  module Repo
    def self.all(queryable, query = Query.new)
      Crecto::Adapters::Postgres.execute(:all, queryable, query)
    end

    def self.get
    end

    def self.first
    end

    def self.find_by
    end

    def self.insert(queryable_instance, *opts)
      Crecto::Adapters::Postgres.execute_on_instance(:insert, queryable_instance, opts)
    end

    def self.update
    end

    def self.delete
    end

    def self.preload
    end

    def self.load
    end
  end
end