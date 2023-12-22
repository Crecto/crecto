# Example repo file. Copy this to `repo.cr` and change the adapter to whatever you want.
module Repo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.uri = "sqlite3://./crecto_test.db"
  end

  # config do |conf|
  #   conf.adapter = Crecto::Adapters::Postgres
  #   conf.uri = "postgres://localhost/crecto_test"
  # end

  # config do |conf|
  #   conf.adapter = Crecto::Adapters::MySQL
  #   conf.uri = "mysql://localhost/crecto_test"
  # end
end
