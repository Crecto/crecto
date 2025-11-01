# Features Guide

This guide highlights the features that are implemented in Crecto today and how to use them safely.

## Schema Definition

Models extend `Crecto::Model` and describe their table structure inside a `schema` block. Supported field types include the Crystal primitives listed in `src/crecto/schema.cr`, plus `JSON`, `UUID`, nullable variants, and arrays of those types.

```crystal
class Product < Crecto::Model
  schema "products" do
    field :name, String
    field :price, Float64
    field :active, Bool, default: true
    field :metadata, Json?
    field :sku, UUID?

    belongs_to :category
    has_many :inventory_entries, InventoryEntry
  end

  validate_required [:name, :price]
end
```

Associations support:

- `belongs_to :category`
- `has_many :inventory_entries, InventoryEntry`
- `has_one :profile`
- `has_many :tags, Tag, through: :inventory_entries`

Many-to-many helpers are not generated automatically; using `has_many ... through:` is the recommended pattern.

## Validations and Changesets

Validations are declared on the model class and run when you build a changeset.

```crystal
class User < Crecto::Model
  schema "users" do
    field :name, String
    field :email, String
    field :age, Int32?
  end

  validate_required [:name, :email]
  validate_format :email, /^[^@\s]+@[^@\s]+\.[^@\s]+$/
  validate_length :name, min: 2
  unique_constraint :email
end

user = User.new
changeset = User.changeset(user)
changeset.valid?         # => false
changeset.errors         # => [{"name", "is required"}, {"email", "is required"}]
```

Keyword initialization uses the same casting pipeline, so `User.new(name: "Ada")` assigns attributes before you build a changeset.

Per-record validations run every time a changeset is instantiated. Mutating repository calls (`insert`, `update`, `delete`) require a valid changeset.

## CRUD Operations

```crystal
Query = Crecto::Repo::Query

# Create
user = User.new.tap do |u|
  u.name = "Sandi"
  u.email = "sandi@example.com"
end

changeset = User.changeset(user)
insert_result = Repo.insert(changeset)

# Update
if insert_result.valid?
  saved_user = insert_result.instance
  saved_user.name = "Sandi Metz"

  update_changeset = User.changeset(saved_user)
  Repo.update(update_changeset)
end

# Delete
Repo.delete(User.changeset(user))

# Fetch
Repo.get(User, 1)
Repo.get_by(User, email: "sandi@example.com")
Repo.all(User, Query.where(active: true).order_by("name ASC"))
```

Remember that `Repo.insert`/`update` return `Changeset` objects. Read operations return model instances directly.

## Query Builder Tips

`Crecto::Repo::Query` supports `where`, `or_where`, string fragments with parameters, ordering, limiting, joining, preloading, and grouping.

```crystal
recent_posts = Query
  .where(published: true)
  .where("published_at > ?", [Time.utc - 30.days])
  .order_by("published_at DESC")
  .limit(10)

Repo.all(Post, recent_posts.preload(:author))
```

To preload multiple associations:

```crystal
Repo.all(User,
  Query.preload(:posts, Query.where(published: true))
       .preload(:profile)
)
```

## Bulk Operations

Use `Repo.insert_all` to insert many records efficiently.

```crystal
records = (1..3).map do |n|
  {name: "Batch User #{n}", email: "batch#{n}@example.com"}
end

result = Repo.insert_all(User, records)

result.successful_count  # number of inserted records
result.failed_count      # zero if all succeeded
result.errors            # details for records that failed validation/DB checks
```

`Repo.update_all` and `Repo.delete_all` accept a `Query` to target matching rows:

```crystal
inactive = Query.where(active: false)
Repo.update_all(User, inactive, {archived_at: Time.utc})
Repo.delete_all(User, Query.where("archived_at < ?", [Time.utc - 90.days]))
```

## Transactions

Group operations with `Crecto::Multi` or use a live transaction when you need immediate feedback.

```crystal
multi = Crecto::Multi.new
multi.insert(User.changeset(user))
multi.insert(Profile.changeset(profile))

result = Repo.transaction(multi)
if result.errors.empty?
  puts "Batch committed"
else
  pp result.errors
end
```

```crystal
Repo.transaction! do |tx|
  tx.insert!(User.changeset(user))
  tx.insert!(Profile.changeset(profile))
end
```

Live transactions yield the same changeset objects returned by the repository. Rolling back is automatic when an exception is raised inside the block.

## Raw SQL Escape Hatch

When the query builder is too limiting, reach for `Repo.query` or `Repo.raw_exec`.

```crystal
Repo.query("UPDATE users SET last_login = ? WHERE id = ?", [Time.utc, 1])

Repo.raw_query("SELECT COUNT(*) FROM users") do |rs|
  rs.each { puts rs.read(Int64) }
end
```

These helpers expect you to close the result set when you work with the lower-level `DB::ResultSet` API directly.
