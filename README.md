# Crecto

Database wrapper for Crystal.  Inspired by [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

---

[![Build Status](https://travis-ci.org/fridgerator/crecto.svg?branch=master)](https://travis-ci.org/fridgerator/crecto) [![Join the chat at https://gitter.im/crecto/Lobby](https://badges.gitter.im/crecto/Lobby.svg)](https://gitter.im/crecto/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

#### [Docs](http://docs.crecto.com)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crecto:
    github: fridgerator/crecto
```

Include a database adapter:

#### Postgres

Include [crystal-pg](https://github.com/will/crystal-pg) in your project

Make sure you have `ENV["PG_URL"]` set

in your application:

```
require "pg"
require "crecto"
```

#### Mysql

Include [crystal-mysql](https://github.com/crystal-lang/crystal-mysql) in your project

Make sure you have `ENV["MYSQL_URL"]` set

in your application:

```
require "mysql"
require "crecto"
```

#### Sqlite

Include [crystal-sqlite3](https://github.com/crystal-lang/crystal-sqlite3) in your project

Make sure you have `ENV["SQLITE3_PATH"]` set

in your appplication:

```
require "sqlite3"
require "crecto"
```

## TODO

#### Roadmap (in no particular order)

- [ ] `default` option for fields
- [x] has_one
- [ ] insert_all
- [x] MySQL adapter
- [x] SQLite adapter
- [x] Associations
- [x] Preload
- [x] Joins
- [x] Repo#aggregate ([ecto link](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/4))
- [ ] [Embeds](https://robots.thoughtbot.com/embedding-elixir-structs-in-ecto-models)
- [x] Transactions / Multi
- [ ] Association / dependent options (`dependent: :delete_all`, `dependent: :nilify_all`, etc)
- [ ] Unique constraint
- [x] Combine database adapters (base class). Currently there is unecessary duplication

## Usage

```crystal
require "#{adapter}" # see above
require "crecto"

# shortcut variables, optional
Repo  = Crecto::Repo
Query = Crecto::Repo::Query
Multi = Crecto::Multi

#
# Define table name, fields and validations in your class
#
class User < Crecto::Model

  schema "users" do
    field :age, Int32 # or use `PkeyValue` alias: `field :age, PkeyValue`
    field :name, String
    field :is_admin, Bool
    field :temporary_info, Float64, virtual: true
    has_many :posts, Post
  end

  validate_required [:name, :age]
  validate_format :name, /[*a-zA-Z]/
end

class Post < Crecto::Model
  
  schema "posts" do
    belongs_to :user, User
  end
end

user = User.new
user.name = "123"
user.age = 123

#
# Check the changeset to see changes and errors
#
changeset = User.changeset(user)
puts changeset.valid? # false
puts changeset.errors # {:field => "name", :message => "is invalid"}
puts changeset.changes # {:name => "123", :age => 123}

user.name = "test"
changeset = User.changeset(user)
changeset.valid? # true

#
# Use Repo to insert into database
#
changeset = Repo.insert(user)
puts changeset.errors # []

#
# User Repo to update database
#
user.name = "new name"
changeset = Repo.update(user)
puts changeset.instance.name # "new name"

#
# Query syntax
#
query = Query
  .where(name: "new name")
  .where("users.age < ?", [124])
  .order_by("users.name ASC")
  .order_by("users.age DESC")
  .limit(1)

#
# All
#
users = Repo.all(User, query)
users.as(Array) unless users.nil?

#
# Get by primary key
#
user = Repo.get(User, 1)
user.as(User) unless user.nil?

#
# Get by fields
#
Repo.get_by(User, name: "new name", id: 1121)
user.as(User) unless user.nil?

#
# Delete
#
changeset = Repo.delete(user)

#
# Associations
#

user = Repo.get(User, id).as(User)
posts = Repo.all(user, :posts)

#
# Preload associations
#
users = Repo.all(User, Query.new, preload: [:posts])
users[0].posts # has_many relation is preloaded

posts = Repo.all(Post, Query.new, preload: [:user])
posts[0].user # belongs_to relation preloaded

#
# Aggregate functions
#
# can use the following aggregate functions: :avg, :count, :max, :min:, :sum
Repo.aggregate(User, :count, :id)
Repo.aggregate(User, :avg, :age, Query.where(name: 'Bill'))

#
# Multi / Transactions
#

# create the multi instance
multi = Multi.new

# build the transactions
multi.insert(insert_user)
multi.delete(post)
multi.delete_all(Comment)
multi.update(update_user)
multi.update_all(User, Query.where(name: "stan"), {name: "stan the man"})
multi.insert(new_user)

# insert the multi using a transaction
Repo.transaction(multi)

# check for errors
# If there are any errors in any of the transactions, the database will rollback as if none of the transactions happened
multi.errors.any?

#
# JSON type (Postgres only)
#

class User < Crecto::Model
  field :settings, Json
end

user = User.new
user.settings = {"one" => "test", "two" => 123, "three" => 12321319323298}

Repo.insert(user)

query = Query.where("settings @> '{\"one\":\"test\"}'")
users = Repo.all(UserJson, query)

#
# Database Logging
#

# By default nothing is logged.  To enable pass any type of IO to the logger.  For STDOUT use:
Crecto::DbLogger.set_handler(STDOUT)

# Write to a file
f = File.open("database.log", "w")
f.sync = true
Crecto::DbLogger.set_handler(f)
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
