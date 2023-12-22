# Crecto

![crecto](crecto.png)

[https://www.crecto.dev/](https://www.crecto.dev/)

[![Build Status](https://travis-ci.org/Crecto/crecto.svg?branch=master)](https://travis-ci.org/Crecto/crecto) [![Join the chat at https://gitter.im/crecto/Lobby](https://badges.gitter.im/crecto/Lobby.svg)](https://gitter.im/crecto/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Robust database wrapper for Crystal. Inspired by [Ecto](https://github.com/elixir-ecto/ecto) for Elixir language.

With built in query composer, associations, transactions, validations, constraints, and more.

Website with guides and examples - [https://www.crecto.dev/](https://www.crecto.dev/)

<!-- See api docs - <http://docs.crecto.dev> -->

## Example

```crystal
user = User.new
user.name = "Shakira"

changeset = Repo.insert(user)
changeset.errors.any?

inserted_user = changeset.instance
inserted_user.name = "Keanu"

changeset = Repo.update(user)
changeset.errors.any?

updated_user = changeset.instance

changeset = Repo.delete(updated_user)
```

## Usage and Guides

New website and API docs coming soon!

<!-- Visit [www.crecto.dev](https://www.crecto.dev) -->

### Benchmarks

- [VS raw crystal-pg](https://github.com/Crecto/crecto/wiki/Benchmarks)

## Development

### Testing

Specs are located in the `specs` directory. Seeing as this is an ORM, running specs does require a database connection
of some kind. Copy the `spec/repo.example.cr` file to `spec/repo.cr` and fill in the connection details for your
database. Then run `crystal spec` to run the specs.

Specs for all three supported database types can be run using docker-compose. Simply run `docker-compose up` to start
the database containers and run the specs.

## Contributing

1. Fork it ( [https://github.com/Crecto/crecto/fork](https://github.com/Crecto/crecto/fork) )
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

- [Ecto](https://github.com/elixir-ecto/ecto)
- [AciveRecord](https://github.com/rails/rails/tree/master/activerecord)
- [active_record.cr](https://github.com/waterlink/active_record.cr)
- [crystal-api-backend](https://github.com/dantebronto/crystal-api-backend)
