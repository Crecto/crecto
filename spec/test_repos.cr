# Multi-database test configurations
# Usage: Set DATABASE_TYPE environment variable to "postgres", "mysql", or "sqlite3"

module TestRepo
  extend Crecto::Repo

  config do |conf|
    database_type = ENV["DATABASE_TYPE"]? || "sqlite3"

    case database_type.downcase
    when "postgres"
      conf.adapter = Crecto::Adapters::Postgres
      conf.database = "crecto_test"
      conf.hostname = ENV["POSTGRES_HOST"]? || "localhost"
      conf.username = ENV["POSTGRES_USER"]? || "postgres"
      conf.password = ENV["POSTGRES_PASSWORD"]? || ""
      conf.port = (ENV["POSTGRES_PORT"]? || "5432").to_i
    when "mysql"
      conf.adapter = Crecto::Adapters::MySQL
      conf.database = "crecto_test"
      conf.hostname = ENV["MYSQL_HOST"]? || "localhost"
      conf.username = ENV["MYSQL_USER"]? || "root"
      conf.password = ENV["MYSQL_PASSWORD"]? || ""
      conf.port = (ENV["MYSQL_PORT"]? || "3306").to_i
    else
      conf.adapter = Crecto::Adapters::SQLite3
      conf.database = "./crecto_test.db"
    end
  end
end

# Convenience modules for specific database testing
module PostgresTestRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "crecto_test"
    conf.hostname = "localhost"
    conf.username = "postgres"
    conf.port = 5432
  end
end

module MysqlTestRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::MySQL
    conf.database = "crecto_test"
    conf.hostname = "localhost"
    conf.username = "root"
    conf.port = 3306
  end
end

module SqliteTestRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./crecto_test.db"
  end
end

# Helper methods for database setup
module TestDatabaseSetup
  extend self

  def setup_database(database_type = "sqlite3")
    case database_type.downcase
    when "postgres"
      setup_postgres
    when "mysql"
      setup_mysql
    else
      setup_sqlite
    end
  end

  def setup_postgres
    # Create test database if it doesn't exist
    system("psql -U postgres -h localhost -c \"CREATE DATABASE crecto_test;\" 2>/dev/null || true")

    # Run migrations
    system("psql -U postgres -h localhost crecto_test < spec/migrations/pg_migrations.sql")
  end

  def setup_mysql
    # Create test database if it doesn't exist
    system("mysql -u root -h localhost -e \"CREATE DATABASE IF NOT EXISTS crecto_test;\"")

    # Run migrations
    system("mysql -u root -h localhost crecto_test < spec/migrations/mysql_migrations.sql")
  end

  def setup_sqlite
    # Remove existing test database
    File.delete("./crecto_test.db") if File.exists?("./crecto_test.db")

    # Run migrations
    system("sqlite3 ./crecto_test.db < spec/migrations/sqlite3_migrations.sql")
  end

  def current_database_type
    ENV["DATABASE_TYPE"]? || "sqlite3"
  end

  def using_postgres?
    current_database_type.downcase == "postgres"
  end

  def using_mysql?
    current_database_type.downcase == "mysql"
  end

  def using_sqlite?
    current_database_type.downcase == "sqlite3"
  end
end
