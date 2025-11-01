# Getting Started

Crecto is an ORM (Object-Relational Mapping) for Crystal, inspired by Elixir's Ecto. It provides a way to map Crystal objects to database tables.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crecto:
    github: Crecto/crecto
```

## Basic Usage

### Defining a Model

```crystal
class User < Crecto::Model
  schema "users" do
    field :name, String
    field :email, String
    field :age, Int32
  end

  validate_required [:name, :email]
  validate_format :email, /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/
end
```

### Setting up a Repository

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

### CRUD Operations

```crystal
# Create
user = User.new(
  name: "John",
  email: "john@example.com",
  age: 30
)

changeset = User.changeset(user)
result = Repo.insert(changeset)
if result.valid?
  created_user = result.instance
end

# Read
users = Repo.all(User)
user = Repo.get(User, 1)

# Update
user.name = "Jane"
changeset = User.changeset(user)
update_result = Repo.update(changeset)

# Delete
changeset = User.changeset(user)
Repo.delete(changeset)
```

### Querying

```crystal
# Find users by name
query = Crecto::Repo::Query.where(name: "John")
users = Repo.all(User, query)

# Complex queries
query = Crecto::Repo::Query
  .where(age: 18..65)
  .where("name LIKE ?", "%John%")
  .order_by("name ASC")
  .limit(10)

users = Repo.all(User, query)
```

## Next Steps

- [Configuration](/configuration) - Learn how to configure your database connection

More documentation coming soon...
