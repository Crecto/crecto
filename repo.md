# Repo

The Repo maps to the datastore through the database adapter, and is used to perform queries.  Multiple Repos can be created and used simultaneously if mapping to multiple data sources is required.

Create a module, named whatever you want, extending `Crecto::Repo`.  Then set the `config` options.

```crystal
module MyRepo
  extend Crecto::Repo

  config do |c|
    c.adapter = Crecto::Adapters::Postgres
    c.uri = ENV["PG_URL"]
  end
end
```

Then use the Repo to run queries:

```crystal
user = User.new
user.name = "James Howlett"
changeset = MyRepo.insert(user)
```

config accepts the following options:

```crystal
config do |c|
  # Choose an adapter for the repo to use: Crecto::Adapters::Postgres, Crecto::Adapters::Mysql, Crecto::Adapters::SQLite3
  c.adapter = Crecto::Adapters::Postgres

  # If `uri` is specified, the remaining config options will be ignored.  uri is usefull if you have an ENV variable with connection settings
  c.uri = ENV["PG_URL"]

  # Datbase path, only used for SQLite3 adpater
  c.database = "/path/to/database.db"

  # Database host
  c.hostname = "localhost"

  # Database port
  c.port = 5432

  # Database name
  c.database = "database_name"

  # Database username
  c.username = "db_username"

  # Database password
  c.password = "password1234"

  # Initial pool size, default 1
  c.initial_pool_size = 1

  # Max pool size, default 0
  c.max_pool_size = 25

  # Max idle pool size, default 1
  c.max_idle_pool_size = 5

  # Checkout timeout, default 5.0
  c.checkout_timeout = 2.5

  # Retry attempts, default 1
  c.retry_attempts = 2

  # Retry delay, default 1.0
  c.retry_delay = 0.5

end
```