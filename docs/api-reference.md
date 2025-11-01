# Crecto API Reference

This reference captures the public APIs that exist in the repository today. All snippets are derived from the current code under `src/crecto`.

## `Crecto::Repo`

Repositories are singletons that wrap a database connection.

### Configuration

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "app_dev"
    conf.username = "postgres"
    conf.password = "postgres"
    conf.hostname = "localhost"
  end
end
```

`config` returns the same `Config` instance every time; use it to tweak settings at boot.

### Reading

- `Repo.all(queryable, query = Crecto::Repo::Query.new, **opts)` – returns an `Array(queryable)`. Optional keyword `preload:` merges extra preloads.
- `Repo.get(queryable, id, tx = nil)` / `Repo.get!(...)`.
- `Repo.get_by(queryable, **opts)` / `Repo.get_by!(...)`.
- `Repo.get_association(model, :name, query = Query.new)` – loads associations on demand.
- `Repo.aggregate(queryable, function, field, query = Query.new)` – executes `AVG/COUNT/MAX/MIN/SUM`.
- `Repo.query(queryable, sql, params = [] of DbValue)` – executes raw SQL, casting rows into models.
- `Repo.query(sql, params = [] of DbValue)` – returns `DB::ResultSet`. Callers must close the result set.
- `Repo.raw_exec(*args)`, `Repo.raw_query(sql, *args)`, `Repo.raw_scalar(*args)` – thin wrappers around the underlying `DB::Database`.

### Writing

All mutating methods expect a valid changeset and return a `Crecto::Changeset::Changeset`.

- `Repo.insert(changeset)` / `Repo.insert!(changeset)`
- `Repo.update(changeset)` / `Repo.update!(changeset)`
- `Repo.delete(changeset)` / `Repo.delete!(changeset)`
- `Repo.insert_all(queryable, Array(Model | Hash | NamedTuple))` – returns `Crecto::BulkResult`. Hashes and named tuples are cast into models before validation.
- `Repo.insert_all!(...)` – raises if any record fails.
- `Repo.update_all(queryable, query, Hash | NamedTuple, tx = nil)` – returns `Nil`.
- `Repo.delete_all(queryable, query = Query.new, tx = nil)` – returns `Nil`.

### Transactions

- `Repo.transaction(multi : Crecto::Multi)` – runs the operations described by the multi and returns the same multi. If any operation fails the transaction is rolled back and `multi.errors` contains the failure details.
- `Repo.transaction! { |tx| ... }` – yields a `Crecto::LiveTransaction`. Any raised exception rolls back.
- `Repo.transaction_with_savepoint!(name = nil) { |tx| ... }` – creates a savepoint when already inside a transaction, otherwise behaves like `transaction!`.

`Crecto::LiveTransaction` exposes the same methods as the repository (`insert`, `update`, `delete`, `insert_all`, `update_all`, `delete_all`, `get`, `get_by`). Each forwards to the repo while reusing the `DB::Transaction`.

## `Crecto::Repo::Query`

The query builder composes SQL fragments.

Common helpers:

- `Query.where(...)`, `Query.or_where(...)` – accept keyword arguments, `(String, Array(DbValue))`, `(Symbol, DbValue)`, or plain SQL.
- `Query.join(:association)` / `Query.join("JOIN ...")`
- `Query.preload(:association, query = Query.new)`
- `Query.order_by("field DESC")`
- `Query.limit(Int32 | Int64)` and `Query.offset(Int32 | Int64)`
- `Query.group_by("expression")`
- `Query.distinct("expression")`
- `Query.combine(other_query)` – merges select lists and where expressions.
- `Query.and { |expr| ... }` and `Query.or { |expr| ... }` – scope combinators.

`Query#stream` and `Query#each_cursor` exist as placeholders and currently raise `NotImplementedError`.

## `Crecto::Model`

Subclassing `Crecto::Model` adds:

- `schema` macro for columns.
- Association macros: `has_many`, `has_one`, `belongs_to`. `has_many` accepts `through:` to model join tables.
- Field introspection: `self.fields`, `self.primary_key_field`, `self.table_name`.
- Initializers: `new`, `new(**attrs)` to apply attributes via the casting pipeline, and `new(named_tuple)` for runtime data.
- Changeset helpers: `self.changeset(instance, validation_context = nil)`, `instance.get_changeset`.
- Casting helpers: `self.cast(hash)`, `instance.cast(hash)`, `cast!(...)`.
- Timestamp helpers: `instance.created_at_to_now`, `instance.updated_at_to_now`.

Associations store metadata in `CRECTO_ASSOCIATIONS` and raise `Crecto::AssociationNotLoaded` until preloaded.

## `Crecto::Changeset`

`Crecto::Changeset::Changeset` instances expose:

- `#valid?` – boolean result.
- `#errors` – `Array(Tuple(String, String))`.
- `#changes` / `#source` – change tracking.
- `#instance` – the wrapped model.
- `#action` – set by the repository (`:insert`, `:update`, `:delete`).
- `#validate_required`, `#validate_format`, etc. – imperative validators run inside custom logic.
- `#unique_constraint(field)` – converts database uniqueness violations into changeset errors.

Validations declared on the model class (e.g. `validate_required`) accumulate in class-level caches and run automatically when a changeset is instantiated.

## `Crecto::Multi`

`Crecto::Multi` collects operations to run inside a transaction.

- `multi.insert(model_or_changeset)`
- `multi.update(model_or_changeset)`
- `multi.delete(model_or_changeset)`
- `multi.delete_all(queryable, query = Crecto::Repo::Query.new)`
- `multi.update_all(queryable, query, update_hash)`
- `multi.operations` – the ordered list of pending operations.
- `multi.errors` – populated when `Repo.transaction(multi)` encounters a failure.
- `multi.changesets_valid?` – returns `false` and sets `errors` if any queued changeset is invalid.

## `Crecto::BulkResult`

Returned by `Repo.insert_all`.

- `#total_count`, `#successful_count`, `#failed_count`
- `#success_rate`
- `#inserted_ids`
- `#errors` – array of `BulkInsertError`
- `#successful?`, `#partial_success?`, `#complete_failure?`
- `#finalize_result(duration_ms)` – called internally to compute `failed_count`.

`BulkInsertError` provides `index`, `error_message`, `error_class`, `validation_errors`, `database_error_code`, and helpers like `#constraint_violation?`.

## Errors

Defined under `src/crecto/errors/`:

- `Crecto::Errors::InvalidChangeset`
- `Crecto::Errors::InvalidAdapter`
- `Crecto::Errors::InvalidOption`
- `Crecto::Errors::InvalidType`
- `Crecto::Errors::AssociationError`
- `Crecto::Errors::AssociationNotLoaded`
- `Crecto::Errors::BulkError`
- `Crecto::Errors::NoResults`
- `Crecto::Errors::ConcurrentModificationError`
- `Crecto::Errors::RecordNotFoundError`
- `Crecto::Errors::IteratorError`

Handle them with Crystal's standard exception mechanisms (`rescue`).

## Logging

`Crecto::DbLogger` captures SQL statements, timings, and bulk operation diagnostics. Adapters call `DbLogger.log` and `DbLogger.log_error` internally. You can configure the logger by assigning `Crecto::DbLogger.logger = Log.for("crecto")`.

---

This reference reflects the behaviour of the code as of the current repository revision. If you add new features, update this document alongside the implementation to keep it trustworthy.
