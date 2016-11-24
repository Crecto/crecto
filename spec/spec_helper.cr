require "spec"
require "../src/crecto"

class User
  include Crecto::Schema
  extend Crecto::Changeset

  schema "users" do
    field :name, String
    field :things, Int32
    field :stuff, Int32, virtual: true
    field :nope, Float64
    field :yep, Bool
    has_many :posts, Post
    has_one :thing, Thing
  end

  validate_required :nope
  validate_required [:name, :things]
  validate_format :name, /[*a-zA-Z]/
end

class UserRequired
  include Crecto::Schema
  extend Crecto::Changeset

  schema "users_required" do
    field :name, String
    field :age, Int32
    field :is_admin, Bool
  end

  validate_required :name
  validate_required [:age, :is_admin]
end

class Thing
  include Crecto::Schema

  schema "things" do
    belongs_to :user, User, foreign_key: "owner_id"
  end
end

class Post
  include Crecto::Schema

  schema "posts" do
    belongs_to :user, User
  end
end

class Tester
	include Crecto::Schema

	schema "testers" do
		field :oof, String
	end	
end