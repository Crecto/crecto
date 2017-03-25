# Schema

<!-- toc -->

The schema is defined in models:

```
class User < Crecto::Model
  schema "users" do  # table name
    field :name, String
    field :age, Int32
    field :is_admin, Bool
    field :temp_info, Float64, virtual: true # virtual fields are not represented in the database and will not persist
    field :user_info, Json # Json field types are only supported by postgres, and will be auto mapped to [JSON::Any](https://crystal-lang.org/api/0.21.1/JSON/Any.html)
    field :some_date, Time

    has_many :posts, Post

    validate_required [:name, :age]
  end
end

class Post < Crecto::Model
  schema "post" do
    field :content, String

    belongs_to :user, User
  end
end
```

* All Int type fields (`Int32`, `Int64`) are automatically cast to `PkeyValue`.  `PkeyValue` is just an alias to `Int32 | Int64 | Nil`
* By default, `schema` assumes 3 fields exist in the database: `id`, `created_at`, `updated_at`.  These can be overriden:

```
field :user_id, primary_key: true
created_at_field "inserted_at"
updated_at_field nil
```

