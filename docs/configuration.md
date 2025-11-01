# Configuration

Crecto uses repositories to manage database connections and operations. Each repository is configured for a specific database.

## PostgreSQL Configuration

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "my_app_dev"
    conf.username = "postgres"
    conf.password = "password"
    conf.hostname = "localhost"
    conf.port = 5432
    conf.initial_pool_size = 1
    conf.max_pool_size = 10
    conf.max_idle_pool_size = 2
    conf.checkout_timeout = 5.0
    conf.retry_attempts = 1
    conf.retry_delay = 1.0
  end
end
```

## MySQL Configuration

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Mysql
    conf.database = "my_app_dev"
    conf.username = "root"
    conf.password = "password"
    conf.hostname = "localhost"
    conf.port = 3306
    conf.initial_pool_size = 1
    conf.max_pool_size = 10
    conf.max_idle_pool_size = 2
    conf.checkout_timeout = 5.0
    conf.retry_attempts = 1
    conf.retry_delay = 1.0
  end
end
```

## SQLite Configuration

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./data/my_app.db"
    conf.initial_pool_size = 1
    conf.max_pool_size = 1
    conf.max_idle_pool_size = 1
    conf.checkout_timeout = 5.0
    conf.retry_attempts = 1
    conf.retry_delay = 1.0
  end
end
```

## URI-based Configuration

You can also use a full database URI instead of individual parameters:

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.uri = "postgres://user:password@localhost:5432/my_app?initial_pool_size=5&max_pool_size=20"
  end
end
```

## Configuration Options

- **adapter**: Database adapter (`Crecto::Adapters::Postgres`, `Crecto::Adapters::Mysql`, `Crecto::Adapters::SQLite3`)
- **database**: Database name (for SQLite, this is the file path)
- **username**: Database username (not applicable for SQLite)
- **password**: Database password (not applicable for SQLite)
- **hostname**: Database host (not applicable for SQLite)
- **port**: Database port (not applicable for SQLite)
- **uri**: Full database URL (alternative to individual parameters)
- **initial_pool_size**: Initial connection pool size (default: 1)
- **max_pool_size**: Maximum connection pool size (default: 0 = unlimited)
- **max_idle_pool_size**: Maximum idle connections in pool (default: 1)
- **checkout_timeout**: Connection checkout timeout in seconds (default: 5.0)
- **retry_attempts**: Number of retry attempts for failed operations (default: 1)
- **retry_delay**: Delay between retry attempts in seconds (default: 1.0)

> **Note:** `retry_attempts` and `retry_delay` are passed through to the underlying Crystal DB driver via the connection string. The bundled adapters do not implement additional automatic retry loops.

## Multiple Repositories

You can define multiple repositories for different databases:

```crystal
class MainRepo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "my_app_main"
    conf.username = "postgres"
    conf.password = "password"
    conf.hostname = "localhost"
    conf.port = 5432
    conf.initial_pool_size = 5
    conf.max_pool_size = 20
  end
end

class AnalyticsRepo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Mysql
    conf.database = "my_app_analytics"
    conf.username = "analytics_user"
    conf.password = "password"
    conf.hostname = "localhost"
    conf.port = 3306
    conf.initial_pool_size = 3
    conf.max_pool_size = 10
  end
end

# Use different repositories
users = MainRepo.all(User)
analytics = AnalyticsRepo.all(AnalyticsEvent)
```

## Environment Variables

You can use environment variables to configure your repositories:

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = ENV["DATABASE_URL"]? || "my_app_dev"
    conf.username = ENV["DB_USERNAME"]? || "postgres"
    conf.password = ENV["DB_PASSWORD"]? || "password"
    conf.hostname = ENV["DB_HOST"]? || "localhost"
    conf.port = (ENV["DB_PORT"]? || "5432").to_i
    conf.max_pool_size = (ENV["DB_POOL_SIZE"]? || "10").to_i
    conf.checkout_timeout = (ENV["DB_TIMEOUT"]? || "5.0").to_f
  end
end
```

## Configuration with URI

For production environments, you might prefer using a complete database URI:

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.uri = ENV["DATABASE_URL"]? || "postgres://postgres:password@localhost:5432/my_app_dev"
  end
end
```

The URI can include connection parameters as query string:
```
postgres://user:pass@host:5432/db?initial_pool_size=5&max_pool_size=20&checkout_timeout=10.0
```
