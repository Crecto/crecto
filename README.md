# crecto

Database wrapper for Crystal.  Based on [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

** JUST STARTED THIS PROJECT, DONT ATTEMPT TO USE IT **

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  crecto:
    github: fridgerator/crecto
```

## TODO

- [ ] Schema
- [ ] Repo
- [ ] Adapters
- [ ] Query class
- [ ] Everything

## Usage

```crystal
require "crecto"

class User
	include Crecto::Schema

	schema "users" do
		field :age, :integer
		field :name, :string
		field :is_admin, :boolean
		field :temporary_info, :float, {virtual: true}
	end
end

u = User.new
u.name = "test"
u.age = 123
Crecto::Repo.insert(u)

query = Crecto::Repo::Query
	.where(name: "test", age: 123)
	.order_by("users.name")
	.limit(1)
Crecto::Repo.all(User, query)
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it ( https://github.com/fridgerator/crecto/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [fridgerator](https://github.com/fridgerator) Nick Franken - creator, maintainer
