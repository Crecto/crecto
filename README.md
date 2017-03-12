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

Include a database adapter (currently only postgres and mysql have been tested)

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

## TODO

#### Roadmap (in no particular order)

- [x] has_one
- [ ] insert_all
- [x] MySQL adapter
- [ ] SQLite adapter
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
require "crecto"

#
# Define table name, fields and validations in your class
#
class User < Crecto::Model

  schema "users" do
    field :age, Int32
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
    field :user_id, PkValue
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
changeset = Crecto::Repo.insert(user)
puts changeset.errors # []

#
# User Repo to update database
#
user.name = "new name"
changeset = Crecto::Repo.update(user)
puts changeset.instance.name # "new name"

#
# Query syntax
#
query = Crecto::Repo::Query
  .where(name: "new name")
  .where("users.age < ?", [124])
  .order_by("users.name ASC")
  .order_by("users.age DESC")
  .limit(1)

#
# All
#
users = Crecto::Repo.all(User, query)
users.as(Array) unless users.nil?

#
# Get by primary key
#
user = Crecto::Repo.get(User, 1)
user.as(User) unless user.nil?

#
# Get by fields
#
Crecto::Repo.get_by(User, name: "new name", id: 1121)
user.as(User) unless user.nil?

#
# Delete
#
changeset = Crecto::Repo.delete(user)

#
# Associations
#

user = Crecto::Repo.get(User, id).as(User)
posts = Crecto::Repo.all(user, :posts)

#
# Preload associations
#
users = Crecto::Repo.all(User, Crecto::Query.new, preload: [:posts])
users[0].posts # has_many relation is preloaded

posts = Crecto::Repo.all(Post, Crecto::Query.new, preload: [:user])
posts[0].user # belongs_to relation preloaded

#
# Aggregate functions
#
# can use the following aggregate functions: :avg, :count, :max, :min:, :sum
Crecto::Repo.aggregate(User, :count, :id)
Crecto::Repo.aggregate(User, :avg, :age, Crecto::Repo::Query.where(name: 'Bill'))

#
# Multi / Transactions
#

# create the multi instance
multi = Crecto::Multi.new

# build the transactions
multi.insert(insert_user)
multi.delete(post)
multi.delete_all(Comment)
multi.update(update_user)
multi.update_all(User, Crecto::Repo::Query.where(name: "stan"), {name: "stan the man"})
multi.insert(new_user)

# insert the multi using a transaction
Crecto::Repo.transaction(multi)

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

Crecto::Repo.insert(user)

query = Crecto::Repo::Query.where("settings @> '{\"one\":\"test\"}'")
users = Crecto::Repo.all(UserJson, query)

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
