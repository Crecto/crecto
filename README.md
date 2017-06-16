# Crecto

Database wrapper for Crystal.  Inspired by [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

---

[![Build Status](https://travis-ci.org/Crecto/crecto.svg?branch=master)](https://travis-ci.org/Crecto/crecto) [![Join the chat at https://gitter.im/crecto/Lobby](https://badges.gitter.im/crecto/Lobby.svg)](https://gitter.im/crecto/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

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

in your application:

```crystal
require "pg"
require "crecto"
```

#### Mysql

Include [crystal-mysql](https://github.com/crystal-lang/crystal-mysql) in your project

in your application:

```crystal
require "mysql"
require "crecto"
```

#### Sqlite

~~Include [crystal-sqlite3](https://github.com/crystal-lang/crystal-sqlite3) in your project~~
Include [zhomarts fork of of crystal-sqlite3](https://github.com/Zhomart/crystal-sqlite3) in your project

in your appplication:

```crystal
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
- [x] Association / dependent options (`dependent: :delete`, `dependent: :nullify`, etc)
- [ ] Unique constraint
- [x] Combine database adapters (base class). Currently there is unecessary duplication

## Migrations

[Micrate](https://github.com/juanedi/micrate) is recommended.  It is used and supported by core crystal members.

## Usage

```crystal

# First create a Repo.  The Repo maps to the datastore and the database adapter and is used to run queries.
# You can even create multiple repos if you need to access multiple databases.
#
# For those coming from Active Record:
#   Repo provides a level of abstraction between database logic (Repo) and business logic (Model).

module Repo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres # or Crecto::Adapters::Mysql or Crecto::Adapters::SQLite3
    conf.database = "database_name"
    conf.hostname = "localhost"
    conf.username = "user"
    conf.password = "password"
    conf.port = 5432
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

#
# Define table name, fields and validations in your model
#
class User < Crecto::Model

  schema "users" do
    field :age, Int32 # or use `PkeyValue` alias: `field :age, PkeyValue`
    field :name, String
    field :is_admin, Bool
    field :temporary_info, Float64, virtual: true
    has_many :posts, Post, dependent: :destroy
  end

  validate_required [:name, :age]
  validate_format :name, /^[a-zA-Z]*$/
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
# Use Repo to insert into database.  Repo returns a new changeset.
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
# Set Associations
#

post = Post.new
post.user = user
Repo.insert(post)

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
posts = Repo.get_association(user, :posts)

post = Repo.get(Post, id).as(Post)
user = Repo.get_association(post, :user)

#
# Preload associations
#
users = Repo.all(User, preload: [:posts])
users[0].posts # has_many relation is preloaded

posts = Repo.all(Post, preload: [:user])
posts[0].user # belongs_to relation preloaded

#
# Nil-check associations
#
# If an association is not loaded, the normal accessor will raise an error.
users = Repo.all(User)
users[0].posts? # => nil
users[0].posts  # raises Crecto::AssociationNotLoaded

# For has_many preloads, the result will always be an array.
users = Repo.all(User, preload: [:posts])
users[0].posts? # => Array(Post)
users[0].posts  # => Array(Post)

# For belongs_to and has_one preloads, the result may still be nil if no
# record exists. If the association is nullable, always use `association?`.
post = Repo.insert(Post.new).instance
post = Repo.get(Post, post.id, preload: [:user])
post.user? # nil
post.user  # raises Crecto::AssociationNotLoaded

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

class UserJson < Crecto::Model
  field :settings, Json
end

user = UserJson.new
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

When developing against crecto, the database must exist prior to
testing. There are migrations for each database type in `spec/migrations`,
and references on how to migrate then in the `.travis.yml` file.

Create a new file `spec/repo.cr` and create a module name `Repo` to use for testing.
There are example repos for each database type in the spec folder: `travis_pg_repo.cr`,
`travis_mysql_repo.cr`, and `travis_sqlite_repo.cr`

When submitting a pull request, please test against all 3 databases.

## Thanks / Inspiration

* [Ecto](https://github.com/elixir-ecto/ecto)
* [AciveRecord](https://github.com/rails/rails/tree/master/activerecord)
* [active_record.cr](https://github.com/waterlink/active_record.cr)
* [crystal-api-backend](https://github.com/dantebronto/crystal-api-backend)
