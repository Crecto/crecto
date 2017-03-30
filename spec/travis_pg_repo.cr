module Repo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "crecto_test"
    conf.hostname = "localhost"
    conf.username = "postgres"
    conf.port = 5432
  end
end