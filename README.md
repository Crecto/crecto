# Crecto

Database wrapper for Crystal.  Inspired by [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

---

[![Build Status](https://travis-ci.org/fridgerator/crecto.svg?branch=master)](https://travis-ci.org/fridgerator/crecto) [![Join the chat at https://gitter.im/crecto/Lobby](https://badges.gitter.im/crecto/Lobby.svg)](https://gitter.im/crecto/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) **[Api Docs](http://docs.crecto.com)**

## Installation

Add crecto to your `shard.yml`:

```yaml
dependencies:
  crecto:
    github: fridgerator/crecto
```

Include a crystal database driver

```crystal
require "pg" # or "mysql" or "sqlite3"
require "crecto"
```

## Quick Start

```crystal
# First create a Repo.  The Repo maps to the datastore and the database adapter and is used to run queries.
# You can even create multiple repos if you need to access multiple databases

module Repo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres # or Crecto::Adapters::Mysql or Crecto::Adapters::SQLite3
    conf.database = "database_name"
    conf.hostname = "localhost"
    conf.username = "user"
    conf.password = "password"
    conf.port = 5342
    # you can also set initial_pool_size, max_pool_size, max_idle_pool_size,
    #  checkout_timeout, retry_attempts, and retry_delay
  end
end

module SqliteRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./path/to/database.db"
  end
end

# shortcut variables, optional
Query = Crecto::Repo::Query
Multi = Crecto::Multi

class User < Crecto::Model

  schema "users" do
    field :age, Int32 # or use `PkeyValue` alias: `field :age, PkeyValue`
    field :name, String
    field :is_admin, Bool
    field :temporary_info, Float64, virtual: true # virtual fields do not persist in the database
  end

  validate_required [:name, :age]
end

# Create using the Repo
user = User.new
user.name = "tester"
user.age = 36

changeset = Repo.insert(user)
changeset.errors? # false
changeset.instance # <#user, id: 1000, name: "tester", age: 36>

# Get
user = Repo.get!(User, 1000)

# Update
user.name = "tested"
changeset = Repo.update(user)

# Delete
Repo.delete(user)
```

## Contributing

1. Fork it ( https://github.com/fridgerator/crecto/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

### Development Notes

When developing against crecto, the database must exist in Postgres prior to
testing. The environment variable `PG_URL` must be set to the database that will
be used for testing. A couple commands have been set up to ease development:

*  `make migrate` - This will remigrate the testing schema to the database.
*  `make spec` - Runs the crystal specs for crecto
*  `make all` - Runs the migration and subsequently runs specs

## Thanks / Inspiration

* [Ecto](https://github.com/elixir-ecto/ecto)
* [active_record.cr](https://github.com/waterlink/active_record.cr)
* [crystal-api-backend](https://github.com/dantebronto/crystal-api-backend)
