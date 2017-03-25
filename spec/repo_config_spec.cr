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
    conf.path = "./some/path/to/db.db"
  end
end

describe "repo config" do
  it "should set the config values for posgres" do
    PgRepoTest.config do |conf|
      conf.adapter.should eq Crecto::Adapters::Postgres
      conf.database.should eq "crecto"
      conf.username.should eq "fred"
      conf.password.should eq "123"
      conf.hostname.should eq "localhost"
      conf.port.should eq 9999
      conf.database_url.should eq "postgres://fred:123@localhost:9999/crecto"
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
      conf.database_url.should eq "mysql://mysql_user:983425@host.name.com:12300/mysql_database"
    end
  end

  it "should set the config values for sqlite" do
    SqliteRepoTest.config do |conf|
      conf.adapter.should eq Crecto::Adapters::SQLite3
      conf.path.should eq "./some/path/to/db.db"
      conf.database_url.should eq "sqlite3://./some/path/to/db.db"
    end
  end
end