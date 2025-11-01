# Advanced Patterns

The existing codebase already covers a few patterns that help when applications grow beyond basic CRUD. This document focuses on what is implemented today.

## Coordinating Work with `Multi`

`Crecto::Multi` batches operations that should be executed inside a single transaction. It is best suited for independent changes where you only need to know whether the batch succeeded.

```crystal
multi = Crecto::Multi.new
multi.insert(User.changeset(user))
multi.insert(Profile.changeset(profile))
multi.update(Post.changeset(post))

result = Repo.transaction(multi)

if result.errors.empty?
  puts "Batch committed"
else
  pp result.errors
end
```

`Multi` validates all queued changesets before opening a transaction. If any are invalid, the transaction will be skipped and `multi.errors` will contain the validation messages.

## Immediate Feedback with `transaction!`

`Repo.transaction!` yields a `Crecto::LiveTransaction`, which forwards calls to the repository while reusing the same low-level `DB::Transaction`.

```crystal
Repo.transaction! do |tx|
  user_result = tx.insert(User.changeset(user))
  raise "user invalid" unless user_result.valid?

  profile = Profile.new.tap { |p| p.user_id = user_result.instance.id }
  profile_result = tx.insert(Profile.changeset(profile))
  raise "profile invalid" unless profile_result.valid?

  # raise will rollback automatically
end
```

Every helper on `LiveTransaction` returns either a changeset or a bulk result—there is no special casing beyond sharing the connection.

## Pagination and Batching

Large result sets should be processed in slices. `Repo.all` accepts `limit` and `offset`, so you can build a loop that paginates manually.

```crystal
Query = Crecto::Repo::Query

offset = 0
batch_size = 500

loop do
  batch = Repo.all(User, Query.limit(batch_size).offset(offset))
  break if batch.empty?

  batch.each { |user| process(user) }
  offset += batch_size
end
```

This approach keeps memory usage predictable even without a streaming cursor API.

## Association Preloading

Preloads fetch related rows in follow-up queries and attach them to existing models. Only `has_many`, `has_one`, `belongs_to`, and `has_many ... through:` associations are supported.

```crystal
users = Repo.all(User,
  Query.preload(:posts, Query.where(published: true))
       .preload(:profile)
)

users.each do |user|
  puts user.profile?.try(&.bio) if user.profile?
  user.posts?.try(&.each) { |post| puts post.title }
end
```

Attempting to access an association that was not preloaded raises `Crecto::AssociationNotLoaded`.

## Bulk Inserts with Error Reporting

`Repo.insert_all` aggregates validation failures and database errors so you can handle partial success gracefully.

```crystal
records = [
  {name: "Alice", email: "alice@example.com"},
  {name: "Bob", email: "bob@example.com"},
  {name: "Invalid", email: "broken"} # fails validation
]

result = Repo.insert_all(User, records)

puts "Inserted #{result.successful_count} / #{result.total_count}"

result.errors.each do |error|
  puts "Index #{error.index} failed: #{error.error_message}"
  pp error.validation_errors
end
```

The adapters insert valid records in bulk and fall back to per-record inserts when a database error occurs, mirroring the behaviour in `src/crecto/adapters/*_adapter.cr`.

These are the patterns supported by the current implementation. Features such as optimistic locking, cursor streaming, or explicit savepoint management are on the roadmap but not yet shipped, so they are intentionally excluded here.
