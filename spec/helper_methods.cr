def quick_create_user(name)
  user = User.new
  user.name = name
  Crecto::Repo.insert(user).instance
end

def quick_create_user_with_things(name, things)
  user = User.new
  user.name = name
  user.things = things
  Crecto::Repo.insert(user).instance
end
