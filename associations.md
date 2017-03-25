# Associations

Crecto supports `has_many`, `belongs_to`, `has_many through:` and `has_one` associations

## Has Many

```
class User < Crecto::Model
	schema "users" do
		has_many :posts, Post
	end
end
```

* `posts` getter and setter will be defined on the `User` model

* Assumes the foreign key to be `user_id`. To specify a different foreign key use: `has_many :posts, Post, foreign_key: :uid`

## Belongs To

```
class Post < Crecto::Model
	schema "posts" do
		belongs_to :user, User
	end
end
```

* `user` getter and setters will be defined on the `Post` model

* Assumes the foreign key to be `user_id`. To specify a different foreign key use: `belongs_to :user, User, foreign_key: :uid`


## Has Many Through

```
class User < Crecto::Model
	schema "users" do
		has_many :user_posts, UserPost
		has_many :posts, Post, through: :user_posts
	end
end

class UserPost < Crecto::Model
	schema "user_posts" do
		belongs_to :user, User
		belongs_to :post, Post
	end
end

class Post < Crecto::Model
	schema "posts" do
		has_many :user_posts, UserPost
		has_many :users, User, through: :user_posts
	end
end
```

## Has One

```
class User < Crecto::Model
	schema "users" do
		has_one :post, Post
	end
end
```