# Performance test models for benchmarking
require "../../src/crecto"
require "json"

class PerformanceUser < Crecto::Model
  schema "performance_users" do
    field :name, String
    field :email, String
    field :age, Int32
    field :active, Bool
    field :created_at, Time
    field :updated_at, Time
  end

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :age, numericality: {greater_than: 0, less_than: 150}

  has_many :posts, PerformancePost, foreign_key: :user_id
end

class PerformancePost < Crecto::Model
  schema "performance_posts" do
    field :title, String
    field :content, String
    field :user_id, Int32
    field :published, Bool
    field :created_at, Time
    field :updated_at, Time
  end

  validates :title, presence: true
  validates :content, presence: true
  validates :user_id, presence: true

  belongs_to :user, PerformanceUser, foreign_key: :user_id
  has_many :comments, PerformanceComment, foreign_key: :post_id
end

class PerformanceComment < Crecto::Model
  schema "performance_comments" do
    field :content, String
    field :post_id, Int32
    field :author_name, String
    field :created_at, Time
  end

  validates :content, presence: true
  validates :post_id, presence: true
  validates :author_name, presence: true

  belongs_to :post, PerformancePost, foreign_key: :post_id
end

# Repository for performance testing
module PerformanceRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "sqlite3:./spec/performance/performance_test.db"
  end
end