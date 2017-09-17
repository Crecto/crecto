require "./spec_helper"
require "./helper_methods"

module PgRepoTest
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "crecto"
    conf.username = "fred"
    conf.password = "123"
    conf.hostname = "localhost"
    conf.initial_pool_size = 2
    conf.max_pool_size = 100
    conf.max_idle_pool_size = 2
    conf.checkout_timeout = 4.5
    conf.retry_attempts = 2
    conf.retry_delay = 0.5
    conf.port = 9999
  end
end

module MysqlRepoTest
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::Mysql
    conf.database = "mysql_database"
    conf.username = "mysql_user"
    conf.password = "983425"
    conf.hostname = "host.name.com"
    conf.port = 12300
  end
end

module SqliteRepoTest
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./some/path/to/db.db"
  end
end

module UriRepoTest
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.uri = "postgres://username:password@localhost:5432/uri_repo_test"
  end
end

describe "repo config" do
  it "should with with a uri, use the uri for the connection string" do
    UriRepoTest.config.database_url.should eq "postgres://username:password@localhost:5432/uri_repo_test"
  end

  it "should set the config values for posgres" do
    PgRepoTest.config do |conf|
      conf.adapter.should eq Crecto::Adapters::Postgres
      conf.database.should eq "crecto"
      conf.username.should eq "fred"
      conf.password.should eq "123"
      conf.hostname.should eq "localhost"
      conf.port.should eq 9999
      conf.initial_pool_size.should eq 2
      conf.max_pool_size.should eq 100
      conf.max_idle_pool_size.should eq 2
      conf.checkout_timeout.should eq 4.5
      conf.retry_attempts.should eq 2
      conf.retry_delay.should eq 0.5
      conf.database_url.should eq "postgres://fred:123@localhost:9999/crecto?initial_pool_size=2&max_pool_size=100&max_idle_pool_size=2&checkout_timeout=4.5&retry_attempts=2&retry_delay=0.5"
    end
  end

  it "should set the config values for mysql" do
    MysqlRepoTest.config do |conf|
      conf.adapter.should eq Crecto::Adapters::Mysql
      conf.database.should eq "mysql_database"
      conf.username.should eq "mysql_user"
      conf.password.should eq "983425"
      conf.hostname.should eq "host.name.com"
      conf.port.should eq 12300
      conf.initial_pool_size.should eq 1
      conf.max_pool_size.should eq 0
      conf.max_idle_pool_size.should eq 1
      conf.checkout_timeout.should eq 5.0
      conf.retry_attempts.should eq 1
      conf.retry_delay.should eq 1.0
      conf.database_url.should eq "mysql://mysql_user:983425@host.name.com:12300/mysql_database?initial_pool_size=1&max_pool_size=0&max_idle_pool_size=1&checkout_timeout=5.0&retry_attempts=1&retry_delay=1.0"
    end
  end

  it "should set the config values for sqlite" do
    SqliteRepoTest.config do |conf|
      conf.adapter.should eq Crecto::Adapters::SQLite3
      conf.database.should eq "./some/path/to/db.db"
      conf.database_url.should eq "sqlite3://./some/path/to/db.db?initial_pool_size=1&max_pool_size=0&max_idle_pool_size=1&checkout_timeout=5.0&retry_attempts=1&retry_delay=1.0"
    end
  end
end
