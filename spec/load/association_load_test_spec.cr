require "spec"
require "./load_test_helper"

# Association Load Testing
# Tests the performance and stability of association operations under sustained load

describe "Association Load Testing" do
  before_all do
    # Setup test database with association tables
    setup_association_test_database
  end

  after_all do
    # Cleanup test database
    cleanup_association_test_database
  end

  describe "Basic Association Load Test" do
    it "handles sustained association operations under high load" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {
          "insert" => 500,
          "update" => 300,
          "delete" => 200,
          "query" => 800,
          "association" => 600
        },
        concurrent_workers: 8
      )

      runner = AssociationLoadTestRunner.new(config)
      stats = runner.run_load_test("Basic Association Operations")

      # Assert basic performance requirements
      stats.success_rate.should be > 90.0
      stats.operations_per_second.should be > 40.0
      stats.memory_usage_mb.should be < 300.0
    end

    it "handles complex association queries under load" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {
          "association" => 1000,
          "query" => 500
        },
        concurrent_workers: 6
      )

      runner = AssociationLoadTestRunner.new(config)
      stats = runner.run_load_test("Complex Association Queries")

      stats.success_rate.should be > 95.0
      stats.operations_per_second.should be > 40.0
    end

    it "handles concurrent association loading with eager loading" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {
          "association" => 800
        },
        concurrent_workers: 6
      )

      runner = AssociationLoadTestRunner.new(config)
      stats = runner.run_load_test("Eager Loading Associations")

      stats.success_rate.should be > 92.0
      stats.operations_per_second.should be > 30.0
    end
  end

  describe "Association Stress Testing" do
    it "handles deep association chains without performance degradation" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {
          "association" => 1000,
          "insert" => 500,
          "query" => 1000
        },
        concurrent_workers: 6
      )
      config.warmup_seconds = 2
      config.cooldown_seconds = 2

      runner = AssociationLoadTestRunner.new(config)
      stats = runner.run_load_test("Deep Association Stress Test")

      stats.success_rate.should be > 85.0
      stats.memory_usage_mb.should be < 400.0
    end
  end
end

# Association test models
class AssociationUser < Crecto::Model
  schema "association_users" do
    field :id, Int64, primary_key: true
    field :name, String
    field :email, String
    field :created_at, Time
  end

  has_many :posts, AssociationPost, foreign_key: :user_id
  has_many :comments, AssociationComment, foreign_key: :user_id
end

class AssociationPost < Crecto::Model
  schema "association_posts" do
    field :id, Int64, primary_key: true
    field :title, String
    field :content, String
    field :user_id, Int64
    field :created_at, Time
  end

  belongs_to :user, AssociationUser, foreign_key: :user_id
  has_many :comments, AssociationComment, foreign_key: :post_id
end

class AssociationComment < Crecto::Model
  schema "association_comments" do
    field :id, Int64, primary_key: true
    field :content, String
    field :user_id, Int64
    field :post_id, Int64
    field :created_at, Time
  end

  belongs_to :user, AssociationUser, foreign_key: :user_id
  belongs_to :post, AssociationPost, foreign_key: :post_id
end

# Association test repository
module AssociationTestRepo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./spec/load/association_test.db"
  end
end

# Association-specific load test runner
class AssociationLoadTestRunner < Crecto::LoadTesting::Runner
  def initialize(config = Crecto::LoadTesting::Config.new)
    super(config, AssociationTestRepo)
    @test_data_lock = Mutex.new
    @user_ids = [] of Int64
    @post_ids = [] of Int64
    @comment_ids = [] of Int64
    @next_user_id = 1_i64
    @next_post_id = 1_i64
    @next_comment_id = 1_i64
  end

  protected def test_insert_operation(stats : Crecto::LoadTesting::Stats)
    # Create a user with posts and comments
    user = AssociationUser.new
    user.name = "Load Test User #{@next_user_id}"
    user.email = "user#{@next_user_id}@loadtest.com"
    user.created_at = Time.local

    user_result = AssociationTestRepo.insert(user)
    unless user_result.is_a?(Crecto::Changeset::Changeset)
      user_id = user_result.id.as(Int64)
      @test_data_lock.synchronize { @user_ids << user_id; @next_user_id += 1 }

      # Create posts for this user
      3.times do |i|
        post = AssociationPost.new
        post.title = "Post #{i} by User #{user_id}"
        post.content = "Content for post #{i} by user #{user_id}"
        post.user_id = user_id
        post.created_at = Time.local

        post_result = AssociationTestRepo.insert(post)
        unless post_result.is_a?(Crecto::Changeset::Changeset)
          post_id = post_result.id.as(Int64)
          @test_data_lock.synchronize { @post_ids << post_id; @next_post_id += 1 }

          # Create comments for this post
          2.times do |j|
            comment = AssociationComment.new
            comment.content = "Comment #{j} on post #{post_id}"
            comment.user_id = user_id
            comment.post_id = post_id
            comment.created_at = Time.local

            comment_result = AssociationTestRepo.insert(comment)
            unless comment_result.is_a?(Crecto::Changeset::Changeset)
              comment_id = comment_result.id.as(Int64)
              @test_data_lock.synchronize { @comment_ids << comment_id; @next_comment_id += 1 }
            end
          end
        end
      end
    end
  end

  protected def test_update_operation(stats : Crecto::LoadTesting::Stats)
    # Update a random user
    user_id = get_random_user_id
    return unless user_id

    user = AssociationTestRepo.get(AssociationUser, user_id)
    return unless user

    user.name = "Updated User #{user_id} at #{Time.local.to_unix}"
    result = AssociationTestRepo.update(user)

    if result.is_a?(Crecto::Changeset::Changeset) && !result.valid?
      raise Exception.new("User update validation failed: #{result.errors}")
    end
  end

  protected def test_delete_operation(stats : Crecto::LoadTesting::Stats)
    # Delete a random user and their associations (cascade)
    user_id = get_random_user_id_for_deletion
    return unless user_id

    user = AssociationTestRepo.get(AssociationUser, user_id)
    return unless user

    result = AssociationTestRepo.delete(user)

    if result.is_a?(Crecto::Changeset::Changeset) && !result.valid?
      raise Exception.new("User delete validation failed: #{result.errors}")
    end

    # Remove from tracking
    @test_data_lock.synchronize do
      @user_ids.delete(user_id)
    end
  end

  protected def test_query_operation(stats : Crecto::LoadTesting::Stats)
    query_type = rand(5)

    case query_type
    when 0
      # Query users with posts
      users = AssociationTestRepo.all(
        AssociationUser,
        Crecto::Repo::Query.limit(10)
      )
    when 1
      # Query posts by user
      user_id = get_random_user_id
      if user_id
        AssociationTestRepo.all(
          AssociationPost,
          Crecto::Repo::Query.where("user_id = ?", user_id).limit(5)
        )
      end
    when 2
      # Query comments by post
      post_id = get_random_post_id
      if post_id
        AssociationTestRepo.all(
          AssociationComment,
          Crecto::Repo::Query.where("post_id = ?", post_id).limit(3)
        )
      end
    when 3
      # Count posts per user
      AssociationTestRepo.aggregate(
        AssociationPost,
        :count,
        :id
      )
    when 4
      # Complex join query simulation
      user_id = get_random_user_id
      if user_id
        AssociationTestRepo.all(
          AssociationPost,
          Crecto::Repo::Query.where("user_id = ? AND created_at > ?", [user_id, Time.local - 1.day]).limit(10)
        )
      end
    end
  end

  protected def test_association_operation(stats : Crecto::LoadTesting::Stats)
    association_type = rand(6)

    case association_type
    when 0
      # Load user with posts (eager loading simulation)
      user_id = get_random_user_id
      if user_id
        user = AssociationTestRepo.get(AssociationUser, user_id)
        if user
          # Simulate eager loading by manually querying posts
          AssociationTestRepo.all(
            AssociationPost,
            Crecto::Repo::Query.where("user_id = ?", user_id)
          )
        end
      end
    when 1
      # Load post with comments
      post_id = get_random_post_id
      if post_id
        post = AssociationTestRepo.get(AssociationPost, post_id)
        if post
          AssociationTestRepo.all(
            AssociationComment,
            Crecto::Repo::Query.where("post_id = ?", post_id)
          )
        end
      end
    when 2
      # Load user's recent comments
      user_id = get_random_user_id
      if user_id
        AssociationTestRepo.all(
          AssociationComment,
          Crecto::Repo::Query.where("user_id = ? AND created_at > ?", [user_id, Time.local - 1.day]).limit(10)
        )
      end
    when 3
      # Get post count per user
      user_id = get_random_user_id
      if user_id
        AssociationTestRepo.aggregate(
          AssociationPost,
          :count,
          :id,
          Crecto::Repo::Query.where("user_id = ?", user_id)
        )
      end
    when 4
      # Get comment count per post
      post_id = get_random_post_id
      if post_id
        AssociationTestRepo.aggregate(
          AssociationComment,
          :count,
          :id,
          Crecto::Repo::Query.where("post_id = ?", post_id)
        )
      end
    when 5
      # Complex association query: Users with posts having comments
      user_id = get_random_user_id
      if user_id
        # Simulate a complex association query
        posts = AssociationTestRepo.all(
          AssociationPost,
          Crecto::Repo::Query.where("user_id = ?", user_id).limit(5)
        )
        posts.each do |post|
          if post.is_a?(AssociationPost)
            AssociationTestRepo.all(
              AssociationComment,
              Crecto::Repo::Query.where("post_id = ?", post.id).limit(3)
            )
          end
        end
      end
    end
  end

  private def get_random_user_id : Int64?
    @test_data_lock.synchronize { @user_ids.empty? ? nil : @user_ids.sample }
  end

  private def get_random_post_id : Int64?
    @test_data_lock.synchronize { @post_ids.empty? ? nil : @post_ids.sample }
  end

  private def get_random_user_id_for_deletion : Int64?
    @test_data_lock.synchronize do
      return nil if @user_ids.size < 5  # Keep minimum users
      @user_ids.empty? ? nil : @user_ids.sample
    end
  end
end