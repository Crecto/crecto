def quick_create_user(name)
  user = User.new
  user.name = name
  Crecto::Repo.insert(user).instance
end

{% for x in ["things", "nope", "yep", "some_date", "pageviews"] %}
def quick_create_user_with_{{x.id}}(name, {{x.id}})
  user = User.new
  user.name = name
  user.{{x.id}} = {{x.id}}
  Crecto::Repo.insert(user).instance
end
{% end %}

def quick_create_post(user)
  post = Post.new
  post.user = user
  Crecto::Repo.insert(post).instance
end
