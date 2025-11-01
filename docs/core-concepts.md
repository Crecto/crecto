# Core Concepts and Architecture

Crecto follows a familiar ORM architecture inspired by Elixir's Ecto. The building blocks are repositories, models, changesets, and database adapters. This document outlines how the pieces fit together in the current codebase.

## Repository Pattern

Repositories encapsulate the database connection and provide the entry point for data access. Define a repository by subclassing `Crecto::Repo` and configuring it with your adapter details.

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "my_app_dev"
    conf.username = "postgres"
    conf.password = "postgres"
    conf.hostname = "localhost"
  end
end
```

The configuration object simply stores the settings and builds a connection URL when `Repo.config.get_connection` is used. You can define multiple repositories by creating additional subclasses that call `config do |conf| ... end`.

### Core Repository Operations

Repository methods return `Crecto::Changeset::Changeset` instances for mutating operations. Always check `changeset.valid?` before using the result.

```crystal
user = User.new
user.name = "Ada"

result = Repo.insert(User.changeset(user))
if result.valid?
  inserted = result.instance
else
  pp result.errors
end
```

Frequently used APIs include:

- `Repo.all(queryable, query = Crecto::Repo::Query.new)` – fetch rows with optional query filters.
- `Repo.get(queryable, id)` / `Repo.get!(...)` – fetch by primary key.
- `Repo.get_by(queryable, **opts)` – fetch the first row matching the given fields.
- `Repo.insert(changeset)`, `Repo.update(changeset)`, `Repo.delete(changeset)` – mutate rows via validated changesets.
- `Repo.insert_all(queryable, records)` – bulk insert arrays of models, hashes, or named tuples. Returns a `Crecto::BulkResult`.
- `Repo.update_all(queryable, query, update_hash)` and `Repo.delete_all(queryable, query)` – perform bulk updates or deletes.
- `Repo.aggregate(queryable, :count, :id)` – run aggregate functions with optional `Query` filters.
- `Repo.query(sql, params)` – execute raw SQL when needed.

### Query Builder

Construct queries with `Crecto::Repo::Query`:

```crystal
Query = Crecto::Repo::Query

recent = Query
  .where(active: true)
  .where("created_at > ?", [Time.utc - 7.days])
  .order_by("created_at DESC")
  .limit(20)

users = Repo.all(User, recent.preload(:profile))
```

Preloading uses the association metadata defined on models (`has_many`, `has_one`, `belongs_to`). Many-to-many relationships are not generated automatically; use `has_many ..., through: ...` if you need join helpers.

### Transactions

- `Repo.transaction(multi)` runs grouped changes described by `Crecto::Multi`.
- `Repo.transaction! { |tx| ... }` yields a `Crecto::LiveTransaction` for executing operations on the same DB transaction and raises on failure.
- `Repo.transaction_with_savepoint!` creates a savepoint when called inside an existing transaction or starts a new transaction otherwise.

Each operation still returns the same changeset objects you would receive from the repository itself.

## Models and Changesets

Models inherit from `Crecto::Model`, which mixes in schema macros, association helpers, and the changeset DSL.

```crystal
class User < Crecto::Model
  schema "users" do
    field :name, String
    field :email, String
    field :age, Int32

    has_many :posts, Post
    belongs_to :account
  end

  validate_required [:name, :email]
  validate_format :email, /^[^@\s]+@[^@\s]+\.[^@\s]+$/
  unique_constraint :email
end
```

Calling `User.changeset(user)` collects validations, casts values, and records errors. You can provide attributes up front with `User.new(name: "Ada")` or call `user.cast(...)` later—both paths use the same casting logic. Associations are only loaded when explicitly preloaded; attempting to access an association that was not preloaded raises `Crecto::AssociationNotLoaded`.

## Adapter Overview

Crecto ships with three adapters:

- `Crecto::Adapters::Postgres`
- `Crecto::Adapters::Mysql`
- `Crecto::Adapters::SQLite3`

All adapters implement the same `Crecto::Adapters::BaseAdapter` contract: they translate query structs, run bulk inserts, and hand back `DB::ResultSet` instances. Bulk inserts rely on multi-row `INSERT` statements. There is no adapter-level streaming cursor API at the moment.

When you call repository operations the adapter receives the active connection (or transaction) plus the requested action. Errors from the underlying driver are converted into changeset errors when possible (for example, uniqueness violations).

## Putting It Together

1. Create a repository subclass and configure it.
2. Define your models with `schema` blocks and validations.
3. Use `Crecto::Repo::Query` to build queries and preload associations.
4. Wrap database writes in changesets and transactions to ensure validations run consistently.

These are the primitives currently implemented in the codebase. Higher-level patterns—such as background streaming or automatic optimistic locking—can be layered on top once the underlying functionality lands.
