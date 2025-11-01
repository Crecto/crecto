# Examples

The snippets below demonstrate how the current API fits together for a simple blog-style application. Each example builds on real behaviour in the repository.

## Database Schema (SQL)

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE comments (
  id SERIAL PRIMARY KEY,
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

## Repository

```crystal
class Repo < Crecto::Repo
  config do |conf|
    conf.adapter = Crecto::Adapters::Postgres
    conf.database = "blog_dev"
    conf.username = "postgres"
    conf.password = "postgres"
    conf.hostname = "localhost"
  end
end
```

## Models

```crystal
class User < Crecto::Model
  schema "users" do
    field :name, String
    field :email, String

    has_many :posts, Post
    has_many :comments, Comment
  end

  validate_required [:name, :email]
  validate_format :email, /^[^@\s]+@[^@\s]+\.[^@\s]+$/
  unique_constraint :email
end

class Post < Crecto::Model
  schema "posts" do
    field :title, String
    field :body, String
    field :published, Bool, default: false

    belongs_to :user
    has_many :comments, Comment
  end

  validate_required [:title, :body]
end

class Comment < Crecto::Model
  schema "comments" do
    field :body, String

    belongs_to :post
    belongs_to :user
  end

  validate_required [:body, :post_id, :user_id]
end
```

## Creating Records

```crystal
user = User.new(
  name: "Chris",
  email: "chris@example.com"
)

user_result = Repo.insert(User.changeset(user))

post_result = nil
if user_result.valid?
  post = Post.new(
    user_id: user_result.instance.id,
    title: "First post",
    body: "Hello world"
  )

  post_result = Repo.insert(Post.changeset(post))
end
```

Use the returned changesets to decide how to proceed:

```crystal
if post_result && !post_result.valid?
  post_result.errors.each do |field, message|
    puts "#{field} #{message}"
  end
end
```

## Loading Data with Preloads

```crystal
Query = Crecto::Repo::Query

recent_posts = Repo.all(
  Post,
  Query.order_by("created_at DESC")
       .limit(10)
       .preload(:user)
       .preload(:comments, Query.preload(:user))
)

recent_posts.each do |post|
  puts "#{post.title} by #{post.user.name}"
  post.comments.each do |comment|
    puts "  #{comment.user.name}: #{comment.body}"
  end
end
```

Accessing an association that was not preloaded raises, so keep the `preload` calls aligned with what you plan to read.

## Updating & Deleting

```crystal
if post = Repo.get(Post, 1)
  post.published = true
  Repo.update(Post.changeset(post))
end

if comment = Repo.get(Comment, 42)
  Repo.delete(Comment.changeset(comment))
end
```

## Using Transactions

```crystal
Repo.transaction! do |tx|
  user_changeset = User.changeset(user)
  result = tx.insert(user_changeset)
  raise "user invalid" unless result.valid?

  comment = Comment.new(
    user_id: result.instance.id,
    post_id: post_id,
    body: "Nice post!"
  )

  comment_result = tx.insert(Comment.changeset(comment))
  raise "comment invalid" unless comment_result.valid?
end
```

An exception will automatically roll back the transaction.

These examples mirror the behaviour of the code under `src/crecto`. Feel free to adapt them to match your own application structure.
