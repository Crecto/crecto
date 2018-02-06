require "pg"
require "../src/crecto"
require "../spec/repo"

Query = Crecto::Repo::Query
Multi = Crecto::Multi

class User < Crecto::Model
  schema "users" do
    field :name, String
    field :things, Int32 | Int64
    field :smallnum, Int16
    field :nope, Float32 | Float64
    field :yep, Bool
    field :some_date, Time
    field :pageviews, Int32 | Int64
    field :unique_field, String
    has_many :posts, Post, foreign_key: :user_id
    has_many :user_projects, UserProject
    has_many :projects, Project, through: :user_projects, dependent: :destroy
  end

  validate_required :name
  unique_constraint :unique_field
end

class Post < Crecto::Model
  schema "posts" do
    belongs_to :user, User
  end
end

class Project < Crecto::Model
  schema "projects" do
    field :name, String
    has_many :user_projects, UserProject
  end
end

class UserProject < Crecto::Model
  schema "user_projects", primary_key: false do
    belongs_to :user, User
    belongs_to :project, Project
  end
end

def random_time
  year = Random.rand(Range.new(1900, 2018))
  month = Random.rand(Range.new(1, 12))
  day = Random.rand(Range.new(1, 28))
  hour = Random.rand(Range.new(1, 12))
  minute = Random.rand(Range.new(1, 59))
  second = Random.rand(Range.new(1, 59))
  Time.new(year, month, day, hour, minute, second)
end

def make_users(save = false)
  users = Array(User).new
  10_000.times do
    user = User.new
    user.name = Random::Secure.hex(8).to_s
    user.things = Random.rand(100)
    user.smallnum = Random.rand(9).to_i16
    user.nope = Random.rand(100.0)
    user.yep = [true, false].sample
    user.some_date = random_time
    users.push(user)
  end
  return users unless save
  users.map { |user| Repo.insert(user).instance }
end
