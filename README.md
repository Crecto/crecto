# Crecto

[![Build Status](https://travis-ci.org/Crecto/crecto.svg?branch=master)](https://travis-ci.org/Crecto/crecto) [![Join the chat at https://gitter.im/crecto/Lobby](https://badges.gitter.im/crecto/Lobby.svg)](https://gitter.im/crecto/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Database wrapper for Crystal.  Inspired by [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

See documentation on <http://docs.crecto.com>

<a href="https://www.buymeacoffee.com/I9Tdb0po3" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/yellow_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crecto:
    github: fridgerator/crecto
```

Include a database adapter:

#### Postgres

Include [crystal-pg](https://github.com/will/crystal-pg) in your project **before** crecto

in your application:

```crystal
require "pg"
require "crecto"
```

#### Mysql

Include [crystal-mysql](https://github.com/crystal-lang/crystal-mysql) in your project **before** crecto

in your application:

```crystal
require "mysql"
require "crecto"
```

#### Sqlite

Include [crystal-sqlite3](https://github.com/crystal-lang/crystal-sqlite3) in your project **before** crecto

in your appplication:

```crystal
require "sqlite3"
require "crecto"
```

## Migrations

[Micrate](https://github.com/amberframework/micrate) is recommended. It is used and supported by core crystal members.

## Usage

First create a Repo.  The Repo maps to the datastore and the database adapter and is used to run queries.
You can even create multiple repos if you need to access multiple databases.

> **Note:** For those coming from Active Record:
> Repo provides a level of abstraction between database logic (Repo) and business logic (Model).

Let's create a repo for Postgres:

```crystal
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
    # checkout_timeout, retry_attempts, and retry_delay
  end
end
```

And another for SQLite:

```crystal
module SqliteRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./path/to/database.db"
  end
end
```

#### Shortcut variables

_Optionally_ you can use constants shorcuts using:

```crystal
Query = Crecto::Repo::Query
Multi = Crecto::Multi
```

#### Definitions

Define table name, fields, validations, and constraints in your model. By default, Crecto assumes your table has the following columns defined `id`, `created_at`, `updated_at`. These are in addition to whatever columns you decide to add.

Defining a new class using `Crecto::Model`:

```crystal
class User < Crecto::Model

  schema "users" do
    field :age, Int32 # or use `PkeyValue` alias: `field :age, PkeyValue`
    field :name, String
    field :is_admin, Bool, default: false
    field :temporary_info, Float64, virtual: true
    field :email, String
    has_many :posts, Post, dependent: :destroy
  end

  validate_required [:name, :age]
  validate_format :name, /^[a-zA-Z]*$/
  unique_constraint :email
end
```

Defining another one:

```crystal
class Post < Crecto::Model

  schema "posts" do
    belongs_to :user, User
  end
end
```

Creating a new `User`:

```crystal
user = User.new
user.name = "123"
user.age = 123
```

If your schema doesn't require the default fields (`id`, `created_at`, `updated_at`), you can ommit them.

```crystal
class UserTags < Crecto::Model
  set_created_at_field nil # or you can set the name of your created_at field
  set_updated_at_field nil # ditto

  # primary_key: false tells the schema there's no `id` field
  schema "user_tags", primary_key: false do
    belongs_to :user, User
    belongs_to :tag, Tag
  end
end
```

For a schema with an ID that is custom (UUID, Random String, etc...)

```crystal
class Comment <  Crecto::Model
  schema "comments" do
    field :id, String, primary_key: true
    field :content, String
  end
end
```

You can check out the `spec/spec_helper.cr` for more examples.

#### Check the changeset to see changes and errors

```crystal
changeset = User.changeset(user)
puts changeset.valid? # false
puts changeset.errors # {:field => "name", :message => "is invalid"}
puts changeset.changes # {:name => "123", :age => 123}

user.name = "test"
changeset = User.changeset(user)
changeset.valid? # true
```

#### Use Repo to insert record into table.

Repo returns a new changeset.

```crystal
changeset = Repo.insert(user)
puts changeset.errors # []
```

#### Use Repo to update record in table.

```crystal
user.name = "new name"
changeset = Repo.update(user)
puts changeset.instance.name # "new name"
```

#### Use Repo to delete record from table.

```crystal
changeset = Repo.delete(user)
```

#### Use Repo to delete all records from table.

```crystal
Repo.delete_all(User)
```

#### Set Associations

```crystal
post = Post.new
post.user = user
Repo.insert(post)
```

#### Query syntax

```crystal
query = Query
  .where(name: "new name")
  .where("users.age < ?", [124])
  .order_by("users.name ASC")
  .order_by("users.age DESC")
  .limit(1)
```

If you need to query through a join table, `Query` also has a `join` method.

```crystal
# SELECT * FROM users INNER JOIN user_tags ON user_tags.user_id = users.id WHERE user_tags.tag_id = ?
query = Query
  .join(:user_tags)
  .where("user_tags.tag_id = ?", 123)
```

One thing to note about the query syntax is that the table you query on isn't decided until you pass the query to `Repo`.

```crystal
query = Query.where(x: 1)

# SELECT * FROM things WHERE x = 1
Repo.all(Thing, query)

# SELECT * FROM weebls WHERE x = 1
Repo.all(Weebl, query)
```

#### All

```crystal
users = Repo.all(User, query)
users.as(Array) unless users.nil?
```

Or you can just get all the records
```crystal
users = Repo.all(User)
users.as(Array) unless users.nil?
```

#### Get by primary key

```crystal
user = Repo.get(User, 1)
user.as(User) unless user.nil?
```

#### Get by fields

```crystal
Repo.get_by(User, name: "new name", id: 1121)
user.as(User) unless user.nil?
```

#### Associations

```crystal
user = Repo.get(User, id).as(User)
posts = Repo.get_association(user, :posts)

post = Repo.get(Post, id).as(Post)
user = Repo.get_association(post, :user)
```

#### Preload associations

```crystal
users = Repo.all(User, preload: [:posts])
users[0].posts # has_many relation is preloaded

posts = Repo.all(Post, preload: [:user])
posts[0].user # belongs_to relation preloaded
```

#### Nil-check associations


If an association is not loaded, the normal accessor will raise an error.

```crystal
users = Repo.all(User)
users[0].posts? # => nil
users[0].posts  # raises Crecto::AssociationNotLoaded
```

For `has_many` preloads, the result will always be an array.

```crystal
users = Repo.all(User, preload: [:posts])
users[0].posts? # => Array(Post)
users[0].posts  # => Array(Post)
```

For belongs_to and has_one preloads, the result may still be nil if no
record exists. If the association is nullable, always use `association?`.

```crystal
post = Repo.insert(Post.new).instance
post = Repo.get(Post, post.id, preload: [:user])
post.user? # nil
post.user  # raises Crecto::AssociationNotLoaded
```

#### Aggregate functions

Can use the following aggregate functions: `:avg`, `:count`, `:max`, `:min:`, `:sum`

```crystal
Repo.aggregate(User, :count, :id)
Repo.aggregate(User, :avg, :age, Query.where(name: 'Bill'))
```


#### Multi / Transactions


Create the multi instance

```crystal
multi = Multi.new
```

#### Build the transactions

```crystal
multi.insert(insert_user)
multi.delete(post)
multi.delete_all(Comment)
multi.update(update_user)
multi.update_all(User, Query.where(name: "stan"), {name: "stan the man"})
multi.insert(new_user)
```


#### Insert the multi using a transaction

```crystal
Repo.transaction(multi)
```

#### Check for errors

If there are any errors in any of the transactions, the database will rollback as if none of the transactions happened

```crystal
multi.errors.any?
```

#### Non-nillable attributes

If you wish to access attributes of a model without having to check for nil, in the case that you are using a `NOT NULL` database constraint you can use the non-nillable attribute accessors.  CAUTION: Mis-use of this could lead to Nil reference runtime errors.

```crystal
user.name!
user.age!
```

#### JSON type

_(Postgres only)_

```crystal
class UserJson < Crecto::Model
  schema "users_json" do
    field :settings, Json
  end
end

user = UserJson.new
user.settings = {"one" => "test", "two" => 123, "three" => 12321319323298}

Repo.insert(user)

query = Query.where("settings @> '{\"one\":\"test\"}'")
users = Repo.all(UserJson, query)
```

#### Array type

_(Postgres only)_

```crystal
class UserArray < Crecto::Model
  schema "users_array" do
    field :string_array, Array(String)
    field :int_array, Array(Int32)
    field :float_array, Array(Float64)
    field :bool_array, Array(Bool)
  end
end

user = UserArray.new
user.string_array = ["one", "two", "three"]

Repo.insert(user)

query = Query.where("? = ANY(string_array)", "one")
users = Repo.all(UserArray, query)
```

#### Database Logging

By default nothing is logged.  To enable pass any type of IO to the logger.  For `STDOUT` use:

```crystal
Crecto::DbLogger.set_handler(STDOUT)
```

##### Write to a file

```crystal
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
