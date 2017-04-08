# Crecto Change Log

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased
* fixed Repo - timezone issue [@metacortex](https://github.com/metacortex)

## [0.5.0] 2017-04-04
* fixed but preventing updating of nil or false values - [@Zhomart](https://github.com/Zhomart)
* **(breaking change)** changed usage of Repo. Repo is now user defined and is where database configuration is set.
* dependent options: `dependent: :delete`, `dependent: :nullify`
* added repo.confi uri option for faster configuration or configuring through a single ENV variable

## [0.4.4] 2017-03-24
* force all Int type fields to `PkeyValue`
* Sqlite3 adapter - [@Zhomart](https://github.com/Zhomart)

## [0.4.3] 2017-03-21
* update to crystal-db 0.4.0

# [0.4.2] 2017-03-21
* added validate_length with array parameter [@metacortex](https://github.com/metacortex)
* supports IS NULL in .where query - `.where(name: nil)`
* schema refactor
* **(breaking change)** added `#get!` and `#get_by` to Repo.  `#get` and `#get_by` will return nil if no record exists (nilable), where `#get!` and `#get_by` will raise an errorif no record exists (not nilable)
* using `belongs_to` association will auto set the foreign key (`belongs_to :user, User` will assume `field :user_id, PkeyValue`)

## [0.4.1] 2017-03-14
* `BaseAdapter` database adapters refactor
* `#distinct` queries
* 'Json' field type (postgres only)
* Database logging
* travis runs postgres AND mysql specs / adapter query specs [@neovintage](https://github.com/neovintage)
* Fix to support unstrict schema mapping (#41) [@huacnlee](https://github.com/huacnlee)
* Fix empty preloads [@huacnlee](https://github.com/huacnlee)

## [0.4.0] 2017-02-26
* `Repo.get` now raises `NoResults` error if no record is found
* MULTI + TRANSACTIONS!

## [0.3.5] 2017-02-21
* `Repo#aggregate` methods
* `has_one` relation type
* added explicit `require "json"`
* `update_all` method override to allow for named tuples

## [0.3.4] 2017-01-06
* fixed has_many through preloads when join association doesn’t exist
* include [`JSON.mapping`](https://crystal-lang.org/api/0.20.4/JSON.html#mapping-macro) in schema

## [0.3.3] 2016-12-31
* close DB::ResultSet after usage (to free pool)

## [0.3.1] 2016-12-28
* Mysql Adapter
* moved association `preload` to `Query` instead of `Repo.all` option
* joins queries and `has_many through` associations

## [0.3.0] 2016-12-17
* Check for result.rows.size in queries - [@neovintage](https://github.com/neovintage)
* `or_where` queries
* `update_all` queries
* `delete_all` queries
* raw (aribtrary) sql queries (i.e. `Crecto::Repo.query("select * from users")`) - [@neovintage](https://github.com/neovintage)
* now using [`crystal-db`](https://github.com/crystal-lang/crystal-db)
* `has_many` associations, with preload
* `belongs_to` assocaitions

## [0.2.0] 2016-11-30
* Added this changelog
* Paramterized queries to prevent SQL Injection
* Generic / proc validations - [@neovintage](https://github.com/neovintage)
* ActiveRecord style validations - [@cjgajard](https://github.com/cjgajard)
* `BIGINT` support - [@neovintage](https://github.com/neovintage)

## 0.1.0
* Schema
* Repo
* Changeset
* Query
* Postgres Adapter

[0.5.0]: https://github.com/fridgerator/crecto/compare/v0.4.4...v0.5.0
[0.4.4]: https://github.com/fridgerator/crecto/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/fridgerator/crecto/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/fridgerator/crecto/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/fridgerator/crecto/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/fridgerator/crecto/compare/v0.3.5...v0.4.0
[0.3.5]: https://github.com/fridgerator/crecto/compare/v0.3.4...v0.3.5
[0.3.4]: https://github.com/fridgerator/crecto/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/fridgerator/crecto/compare/v0.3.1...v0.3.3
[0.3.1]: https://github.com/fridgerator/crecto/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/fridgerator/crecto/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/fridgerator/crecto/compare/0.1.0...v0.2.0
