# Integration test models for comprehensive end-to-end testing
require "../../src/crecto"

class IntegrationUser < Crecto::Model
  schema "integration_users" do
    field :username, String
    field :email, String
    field :password_hash, String
    field :profile_complete, Bool
  end

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :password_hash, presence: true

  has_one :profile, IntegrationProfile, foreign_key: :user_id
  has_many :posts, IntegrationPost, foreign_key: :author_id
end

class IntegrationProfile < Crecto::Model
  schema "integration_profiles" do
    field :user_id, PkeyValue
    field :first_name, String
    field :last_name, String
    field :bio, String
    field :avatar_url, String
    field :location, String
    field :website, String
  end

  validates :user_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true

  belongs_to :user, IntegrationUser, foreign_key: :user_id
end

class IntegrationCategory < Crecto::Model
  schema "integration_categories" do
    field :name, String
    field :description, String
  end

  validates :name, presence: true, uniqueness: true

  has_many :posts, IntegrationPost, foreign_key: :category_id
end

class IntegrationPost < Crecto::Model
  schema "integration_posts" do
    field :title, String
    field :content, String
    field :author_id, PkeyValue
    field :category_id, PkeyValue
    field :status, String
    field :view_count, Int32
  end

  validates :title, presence: true
  validates :content, presence: true
  validates :author_id, presence: true
  validates :category_id, presence: true
  validates :status, inclusion: {in: ["draft", "published", "archived"]}

  belongs_to :author, IntegrationUser, foreign_key: :author_id
  belongs_to :category, IntegrationCategory, foreign_key: :category_id
  has_many :comments, IntegrationComment, foreign_key: :post_id
end

class IntegrationComment < Crecto::Model
  schema "integration_comments" do
    field :content, String
    field :author_name, String
    field :author_email, String
    field :post_id, PkeyValue
    field :approved, Bool
  end

  validates :content, presence: true
  validates :author_name, presence: true
  validates :author_email, presence: true
  validates :post_id, presence: true

  belongs_to :post, IntegrationPost, foreign_key: :post_id
end

# Repository for integration testing
module IntegrationRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./spec/integration/integration_test.db"
  end
end