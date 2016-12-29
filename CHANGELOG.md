# Crecto Change Log

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased

# [0.3.1] 2016-12-28
* Mysql Adapter
* moved association `preload` to `Query` instead of `Repo.all` option
* joins queries and `has_many through` associations

# [0.3.0] 2016-12-17
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

[0.3.1]: https://github.com/fridgerator/crecto/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/fridgerator/crecto/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/fridgerator/crecto/compare/0.1.0...v0.2.0
