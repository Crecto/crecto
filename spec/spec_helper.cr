module PG
  struct Numeric
    def to_f
    end
  end
end

require "pg"
require "mysql"
require "sqlite3"
require "uuid"
require "spec"
require "../src/crecto"
require "./repo"

alias TestFloat = PG::Numeric | Float64

Query = Crecto::Repo::Query
Multi = Crecto::Multi

class DefaultValue < Crecto::Model
  schema "default_values" do
    field :default_string, String, default: "should set default"
    field :default_int, Int32, default: 64
    field :default_float, Float64, default: 3.14
    field :default_time, Time, default: Time.local
    field :default_bool, Bool, default: false
  end
end

class User < Crecto::Model
  schema "users" do
    field :name, String
    field :things, Int32 | Int64
    field :stuff, Int32, virtual: true
    field :smallnum, Int16
    field :nope, Float32 | Float64
    field :yep, Bool
    field :some_date, Time
    field :pageviews, Int32 | Int64
    field :unique_field, String
    has_many :posts, Post, foreign_key: :user_id
    has_one :post, Post
    has_many :addresses, Address, dependent: :destroy
    has_many :user_projects, UserProject
    has_many :projects, Project, through: :user_projects, dependent: :destroy
  end

  validate_required :name
  unique_constraint :unique_field
end

class Project < Crecto::Model
  schema "projects" do
    field :name, String
    has_many :user_projects, UserProject
  end
end

class UserProject < Crecto::Model
  set_created_at_field nil
  set_updated_at_field nil

  schema "user_projects", primary_key: false do
    belongs_to :user, User
    belongs_to :project, Project
  end
end

class UserDifferentDefaults < Crecto::Model
  set_created_at_field "xyz"
  set_updated_at_field nil

  schema "users_different_defaults" do
    field :user_id, PkeyValue, primary_key: true
    field :name, String
    has_many :things, Thing, dependent: :nullify
  end

  validate_required :name
end

class UserLargeDefaults < Crecto::Model
  set_created_at_field nil
  set_updated_at_field nil

  schema "users_large_defaults" do
    field :id, Int32 | Int64, primary_key: true
    field :name, String
  end
end

class UserArrays < Crecto::Model
  schema "users_arrays" do
    field :string_array, Array(String)
    field :int_array, Array(Int32)
    field :float_array, Array(Float64)
    field :bool_array, Array(Bool)
  end
end

class UserRequired < Crecto::Model
  schema "users_required" do
    field :name, String
    field :age, Int32
    field :is_admin, Bool
  end

  validate_required :name
  validate_required [:age, :is_admin]
end

class UserFormat < Crecto::Model
  schema "users_required" do
    field :name, String
    field :age, Int32
    field :is_admin, Bool
  end

  validate_format :name, /[*a-zA-Z]/
end

class UserInclusion < Crecto::Model
  schema "users_required" do
    field :name, String
    field :age, Int32
    field :is_admin, Bool
  end

  validate_inclusion :name, ["bill", "ted"]
end

class UserExclusion < Crecto::Model
  schema "users_required" do
    field :name, String
    field :age, Int32
    field :is_admin, Bool
  end

  validate_exclusion :name, ["bill", "ted"]
end

class UserLength < Crecto::Model
  schema "users_required" do
    field :name, String
    field :age, Int32
    field :is_admin, Bool
  end

  validate_length :name, max: 5
end

class UserGenericValidation < Crecto::Model
  schema "user_generic" do
    field :id, Int32, primary_key: true
    field :password, String, virtual: true
    field :encrypted_password, String
  end

  validate "Password must exist", ->(user : UserGenericValidation) do
    return false if user.id.nil? || user.id == ""
    return true unless password = user.password
    !password.empty?
  end
end

class UserMultipleValidations < Crecto::Model
  schema "users" do
    field :first_name, String
    field :last_name, String
    field :rank, Int32
  end

  validates :first_name,
    length: {min: 3, max: 9}

  validates [:first_name, :last_name],
    presence: true,
    format: {pattern: /^[a-zA-Z]+$/},
    exclusion: {in: ["foo", "bar"]}

  validates :rank,
    inclusion: {in: 1..100}
end

class Address < Crecto::Model
  schema "addresses" do
    belongs_to :user, User
  end
end

class Post < Crecto::Model
  schema "posts" do
    belongs_to :user, User
  end
end

class Thing < Crecto::Model
  schema "things" do
    belongs_to :user, UserDifferentDefaults, foreign_key: :user_different_defaults_id
  end
end

class UserJson < Crecto::Model
  schema "users_json" do
    field :settings, Json
  end
end

class UserUUID < Crecto::Model
  schema "users_uuid" do
    field :uuid, String, primary_key: true
    field :name, String
  end
end

class UserUUIDCustom < Crecto::Model
  schema "users_uuid_custom" do
    field :id, String, primary_key: true
    field :name, String
  end
end

class ThingThatBelongsToUserUUIDCustom < Crecto::Model
  schema "things_that_belong_to_user_uuid_custom" do
    field :id, String, primary_key: true
    field :name, String
    belongs_to :user_uuid_custom, UserUUIDCustom
  end
end

class Vehicle < Crecto::Model
  enum State
    OFF
    STARTING
    RUNNING
  end

  enum Make
    COUPE
    SEDAN
    HATCH
    TRUCK
  end

  schema "vehicles" do
    enum_field :state, State
    enum_field :make, Make, column_name: "vehicle_type", column_type: Int32
  end
end

class ThingWithoutFields < Crecto::Model
  schema "things_without_fields" do
  end
end

# Additional test models for association IndexError testing
class ComplexUser < Crecto::Model
  schema "users" do
    field :name, String
    field :email, String
    has_many :complex_posts, ComplexPost
    has_many :complex_comments, ComplexComment
    has_one :user_profile, UserProfile
  end
end

class ComplexPost < Crecto::Model
  schema "posts" do
    field :title, String
    field :content, String
    belongs_to :complex_user, ComplexUser
    has_many :complex_comments, ComplexComment
  end
end

class ComplexComment < Crecto::Model
  schema "comments" do
    field :content, String
    belongs_to :complex_post, ComplexPost
    belongs_to :complex_user, ComplexUser
  end
end

class UserProfile < Crecto::Model
  schema "addresses" do
    field :bio, String
    field :avatar_url, String
    belongs_to :complex_user, ComplexUser
  end
end

# Models for testing UUID associations
class UserWithUuid < Crecto::Model
  schema "users_uuid" do
    field :uuid, String, primary_key: true
    field :name, String
    has_many :posts_with_uuid, PostWithUuid, foreign_key: :user_uuid
  end
end

class PostWithUuid < Crecto::Model
  schema "posts" do
    field :id, Int32, primary_key: true
    field :title, String
    belongs_to :user_with_uuid, UserWithUuid, foreign_key: :user_uuid, primary_key: :uuid
  end
end

# This allows us to see the sql generated by crecto and validate
# it against expectations on the the adapters
def check_sql(&)
  yield Crecto::Adapters.sqls
end

module Crecto::Adapters
  @@SQLS = [] of String

  def self.sqls
    @@SQLS
  end

  def self.clear_sql
    @@SQLS.clear
  end

  module BaseAdapter
    def execute(conn, query_string, params)
      Crecto::Adapters.sqls << query_string
      previous_def(conn, query_string, params)
    end

    def execute(conn, query_string)
      Crecto::Adapters.sqls << query_string
      previous_def(conn, query_string)
    end
  end
end
