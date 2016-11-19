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
- [ ] Everything

## Usage

```crystal
require "crecto"

class User
	include Crecto::Schema

	schema "users" do
		field :id, :ineger, {primary_key: true}
		field :name, :string
		field :is_admin, :boolean
		field :temporary_info, :float, {virtual: true}
	end
end
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
