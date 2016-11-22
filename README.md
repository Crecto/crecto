# Crecto

Database wrapper for Crystal.  Based on [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

** WORK IN PROGRESS **

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crecto:
    github: fridgerator/crecto
```

## TODO

- [ ] Choose adapter in config
- [ ] Different primary key
- [ ] deal with created_at & updated_at
- [ ] Associations
- [ ] Validations
- [ ] Callbacks
- [ ] Preload
- [ ] Joins

## Usage

```crystal
require "crecto"

class User
	include Crecto::Schema

	schema "users" do
		field :age, Int32
		field :name, String
		field :is_admin, Bool
		field :temporary_info, Float64, virtual: true
	end
end

user = User.new
user.name = "test"
user.age = 123
Crecto::Repo.insert(user)

user.name = "new name"
Crecto::Repo.update(user)

query = Crecto::Repo::Query
	.where(name: "new name", age: 123)
	.order_by("users.name")
	.limit(1)
	
users = Crecto::Repo.all(User, query)
users.as(Array) unless users.nil?

user = Crecto::Repo.get(User, 1)
user.as(User) unless user.nil?

Crecto::Repo.get_by(User, name: "new name", id: 1121)
user.as(User) unless user.nil?

Crecto::Repo.delete(user)
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

## Thanks / Inspiration

* [Ecto](https://github.com/elixir-ecto/ecto)
* [active_record.cr](https://github.com/waterlink/active_record.cr)
* [crystal-api-backend](https://github.com/dantebronto/crystal-api-backend)

## License

The MIT License

Copyright (c) 2010-2016 Google, Inc. http://angularjs.org

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.