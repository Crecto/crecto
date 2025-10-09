# crecto Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-09

## Active Technologies
- Crystal 1.17.1 + crystal-db, crystal-pg (~> 0.23.2), crystal-mysql (~> 0.13.0), crystal-sqlite3 (~> 0.18.0) (001-improve-overall-quality)

## Project Structure
```
src/
tests/
```

## Commands
- `crystal spec` - Run test suite
- `crystal spec spec/schema_spec.cr` - Run specific test file
- `sqlite3 crecto_test.db < spec/migrations/sqlite3_migrations.sql` - Setup SQLite test database
- `DATABASE_TYPE=postgres crystal spec` - Run tests with PostgreSQL
- `DATABASE_TYPE=mysql crystal spec` - Run tests with MySQL

## Code Style
Crystal 1.17.1: Follow standard conventions

## Recent Changes
- 001-improve-overall-quality: Fixed Crystal macro compatibility for union types, added multi-database test configurations, enhanced test models for association testing

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->