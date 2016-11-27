# Crecto [![Build Status](https://travis-ci.org/fridgerator/crecto.svg?branch=master)](https://travis-ci.org/fridgerator/crecto)

Database wrapper for Crystal.  Inspired by [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crecto:
    github: fridgerator/crecto
```

## TODO

#### Roadmap (in no particular order)

- [ ] OR WHERE
- [ ] DELETE ALL (with an array or no arguments will clear the table)
- [ ] UPDATE ALL
- [ ] Benchmark vs Active Record
- [ ] Choose adapter in config
- [ ] Associations
- [ ] Preload
- [ ] Joins

## Usage

```crystal
require "crecto"

#
# Define table name, fields and validations in your class
#
class User
  include Crecto::Schema
  extend Crecto::Changeset

  schema "users" do
    field :age, Int32
    field :name, String
    field :is_admin, Bool
    field :temporary_info, Float64, virtual: true
  end

  validate_required [:name, :age]
  validate_format :name, /[*a-zA-Z]/
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
  .where("users.age < 124")
  .order_by("users.name ASC")
  .order_by("users.age DESC")
  .limit(1)

#
# all
#
users = Crecto::Repo.all(User, query)
users.as(Array) unless users.nil?

#
# get by primary key
#
user = Crecto::Repo.get(User, 1)
user.as(User) unless user.nil?

#
# get by fields
#
Crecto::Repo.get_by(User, name: "new name", id: 1121)
user.as(User) unless user.nil?

#
# delete
#
changeset = Crecto::Repo.delete(user)
```

## Performance

#### crystal:
	
* crystal 0.20.0

`elapsed: 2.6528820` seconds

```Crystal
require "crecto"

class User
  include Crecto::Schema
  extend Crecto::Changeset(User)

  schema "users" do
    field :name, String
    field :things, Int32
    field :stuff, Int32, virtual: true
    field :nope, Float64
    field :yep, Bool
    field :some_date, Time
  end

  validate_required :name
  validate_format :name, /[*a-zA-Z]/
  validate_inclusion :name, ["fridge", "mcridge"]
  validate_length :name, min: 2, max: 10
end

start_time = Time.now
10000.times do
  user = User.new
  user.name = "fridge"
  changeset = User.changeset(user)
  changeset = Crecto::Repo.insert(changeset)
end
end_time = Time.now
puts "elapsed: #{end_time - start_time}"
```

#### Ruby / Rails

* ruby 2.3.1
* rails 5.0.0

`elapsed: 14.624411` seconds

```Ruby
class User < ApplicationRecord
  validates :name,
    presence: true, 
    inclusion: { in: ["fridge", "mcridge"] }, 
    format: { with: /[*a-zA-Z]/ }, 
    length: { minimum: 2, maximum: 10 }
end

start_time = Time.now
10000.times do
  u = User.new
  u.name = "fridge"
  u.save
end
end_time = Time.now
puts "elapsed: #{end_time-start_time}"
```

## Contributing

1. Fork it ( https://github.com/fridgerator/crecto/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [fridgerator](https://github.com/fridgerator) Nick Franken - creator, maintainer

## Thanks / Inspiration

* [Ecto](https://github.com/elixir-ecto/ecto)
* [active_record.cr](https://github.com/waterlink/active_record.cr)
* [crystal-api-backend](https://github.com/dantebronto/crystal-api-backend)
