# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
- **Run all tests**: `crystal spec` (uses SQLite by default)
- **Run tests with specific database**: Set `DATABASE_TYPE` environment variable:
  - PostgreSQL: `DATABASE_TYPE=postgres crystal spec`
  - MySQL: `DATABASE_TYPE=mysql crystal spec`
  - SQLite: `DATABASE_TYPE=sqlite3 crystal spec` (default)

### Database Setup for Testing
- **Quick setup (SQLite)**: Just run `crystal spec` - the database will be created automatically
- **PostgreSQL setup**:
  - Create database: `psql -U postgres -h localhost -c "CREATE DATABASE crecto_test;"`
  - Run migrations: `psql -U postgres -h localhost crecto_test < spec/migrations/pg_migrations.sql`
- **MySQL setup**:
  - Create database: `mysql -u root -h localhost -e "CREATE DATABASE IF NOT EXISTS crecto_test;"`
  - Run migrations: `mysql -u root -h localhost crecto_test < spec/migrations/mysql_migrations.sql`

### Docker Testing
- **Test all databases**: `docker-compose up` (runs tests against PostgreSQL, MySQL, and SQLite)

### Build & Format
- **Format code**: `crystal tool format`
- **Check formatting**: `crystal tool format --check` (used in CI)

## Code Architecture

### Core Components

**Crecto** is an ORM (Object-Relational Mapping) for Crystal, inspired by Elixir's Ecto. The architecture follows several key patterns:

#### Repository Pattern (`src/crecto/repo.cr`)
- `Repo` module handles all database operations
- Supports CRUD operations: `all`, `get`, `insert`, `update`, `delete`
- Provides query composition through `Crecto::Repo::Query`
- Manages transactions and associations
- All database operations go through adapters

#### Model System (`src/crecto/model.cr`, `src/crecto/schema.cr`)
- Models extend `Crecto::Model` or include `Crecto::Schema`
- Uses Crystal macros for field definitions and type safety
- Supports:
  - Field definitions with types
  - Associations (has_many, has_one, belongs_to)
  - Validations
  - Changesets for data modification
  - Timestamps (created_at, updated_at)

#### Changeset Pattern (`src/crecto/changeset.cr`)
- Changesets track data changes and validation errors
- Provide data validation and transformation before database operations
- Support required fields, format validation, inclusion/exclusion, custom validations
- Enable safe data updates with error handling

#### Adapter System (`src/crecto/adapters/`)
- Database adapters provide abstraction layer over different databases
- Currently supports: PostgreSQL, MySQL, SQLite3
- Each adapter implements the same interface for database operations
- Adapters handle SQL generation and type mapping for their specific database

#### Association System (`src/crecto/schema/associations.cr`)
- Supports `has_many`, `has_one`, and `belongs_to` associations
- Handles eager loading (preloading) of associations
- Manages dependent operations (destroy, nullify)
- Supports `has_many :through` associations for many-to-many relationships

### Key Architectural Patterns

1. **Macro-heavy Schema Definition**: Uses Crystal's compile-time macros to generate
   database field mappings, associations, and type-safe accessors

2. **Changeset-based Updates**: All modifications go through changesets, providing
   validation, casting, and error handling before database operations

3. **Query Composition**: Database queries are built using a fluent interface
   that composes conditions, ordering, limits, and preloading

4. **Multi-database Support**: Clean abstraction allows same model code to work
   with PostgreSQL, MySQL, and SQLite3

5. **Type Safety**: Leverages Crystal's type system for compile-time checking
   of field types and associations

### Testing Architecture

The test suite uses multiple test models defined in `spec/spec_helper.cr`:
- Test models cover all association types and validation scenarios
- Each database adapter has its own test configuration
- SQL capture mechanism allows testing generated queries against expectations
- Database migrations are provided for each supported database type

### Configuration System

Repositories are configured using the `config` block:
- Adapter selection (Postgres, MySQL, SQLite3)
- Database connection parameters
- Connection pooling settings
- Logging configuration

The test configuration in `spec/test_repos.cr` shows how to set up
multi-database testing using environment variables.