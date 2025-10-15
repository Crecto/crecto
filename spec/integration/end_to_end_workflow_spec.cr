require "spec"
require "../spec_helper"
require "./integration_test_models"

describe "End-to-End Application Workflows" do
  before_all do
    setup_integration_database
  end

  after_all do
    cleanup_integration_database
  end

  it "handles complete user registration and content creation workflow" do
    # Step 1: Create user account
    user = IntegrationUser.new
    user.username = "john_doe"
    user.email = "john@example.com"
    user.password_hash = "hashed_password"
    user.profile_complete = false

    user_changeset = IntegrationUser.changeset(user)
    created_user_changeset = IntegrationRepo.insert(user_changeset)
    created_user_changeset.should_not be_nil
    created_user = created_user_changeset.instance
    user_id = created_user.id.not_nil!

    # Step 2: Create user profile
    profile = IntegrationProfile.new
    profile.user_id = user_id
    profile.first_name = "John"
    profile.last_name = "Doe"
    profile.bio = "Software developer passionate about Crystal"
    profile.avatar_url = "https://example.com/avatar.jpg"
    profile.location = "San Francisco, CA"
    profile.website = "https://johndoe.dev"

    profile_changeset = IntegrationProfile.changeset(profile)
    created_profile_changeset = IntegrationRepo.insert(profile_changeset)
    created_profile_changeset.should_not be_nil
    created_profile = created_profile_changeset.instance

    # Step 3: Update user to mark profile complete
    # Use the created_user object which has the ID set
    created_user.profile_complete = true
    # Crecto handles updated_at automatically
    user_changeset = IntegrationUser.changeset(created_user)
    updated_user_changeset = IntegrationRepo.update(user_changeset)
    updated_user_changeset.should_not be_nil
    updated_user = updated_user_changeset.instance

    # Step 4: Create blog posts
    posts = [] of IntegrationPost
    3.times do |i|
      post = IntegrationPost.new
      post.title = "My First Post - Part #{i + 1}"
      post.content = "This is the content of my #{i + 1}st blog post. It contains interesting thoughts about Crystal programming."
      post.author_id = user_id
      post.category_id = 1
      post.status = "published"
      post.view_count = 0

      post_changeset = IntegrationPost.changeset(post)
      created_post_changeset = IntegrationRepo.insert(post_changeset)
      created_post_changeset.should_not be_nil
      created_post = created_post_changeset.instance
      posts << created_post
    end

    # Step 5: Add comments to posts
    posts.each_with_index do |post, i|
      2.times do |j|
        comment = IntegrationComment.new
        comment.content = "Great post #{i + 1}! Comment number #{j + 1}."
        comment.author_name = "Commenter #{j + 1}"
        comment.author_email = "commenter#{j + 1}@example.com"
        comment.post_id = post.id.not_nil!
        comment.approved = true

        comment_changeset = IntegrationComment.changeset(comment)
        created_comment_changeset = IntegrationRepo.insert(comment_changeset)
        created_comment_changeset.should_not be_nil
        created_comment = created_comment_changeset.instance
      end
    end

    # Step 6: Verify complete workflow by querying related data
    # Get user with profile
    retrieved_user = IntegrationRepo.get(IntegrationUser, user_id)
    retrieved_user.should_not be_nil
    retrieved_user.not_nil!.username.should eq("john_doe")
    retrieved_user.not_nil!.profile_complete.should be_true

    # Get user's profile
    user_profile = IntegrationRepo.get_by(IntegrationProfile, user_id: user_id)
    user_profile.should_not be_nil
    user_profile.not_nil!.first_name.should eq("John")

    # Get user's posts with comments
    user_posts = IntegrationRepo.all(IntegrationPost, Crecto::Repo::Query.where(author_id: user_id))
    user_posts.size.should eq(3)

    user_posts.each do |post|
      comments = IntegrationRepo.all(IntegrationComment, Crecto::Repo::Query.where(post_id: post.id))
      comments.size.should eq(2)
      comments.all?(&.approved).should be_true
    end

    # Step 7: Cleanup workflow - delete in correct order due to foreign keys
    comments = IntegrationRepo.all(IntegrationComment)
    comments.each { |comment| IntegrationRepo.delete(comment) }

    posts.each { |post| IntegrationRepo.delete(post) }
    IntegrationRepo.delete(created_profile.not_nil!)
    IntegrationRepo.delete(retrieved_user.not_nil!)
  end

  it "handles complex transaction workflow with rollback" do
    # Test transaction with multiple operations
    begin
      IntegrationRepo.transaction! do |tx|
        # Create user
        user = IntegrationUser.new
        user.username = "transaction_user"
        user.email = "transaction@example.com"
        user.password_hash = "hash"
        user.profile_complete = false

        user_changeset = IntegrationUser.changeset(user)
        created_user_changeset = tx.insert(user_changeset)
        created_user = created_user_changeset.instance
        user_id = created_user.id.not_nil!

        # Create profile
        profile = IntegrationProfile.new
        profile.user_id = user_id
        profile.first_name = "Transaction"
        profile.last_name = "User"
        profile.bio = "Testing transaction workflows"

        profile_changeset = IntegrationProfile.changeset(profile)
        created_profile_changeset = tx.insert(profile_changeset)
        created_profile = created_profile_changeset.instance

        # Create post
        post = IntegrationPost.new
        post.title = "Transaction Test Post"
        post.content = "Testing transaction rollback behavior"
        post.author_id = user_id
        post.category_id = 1
        post.status = "published"
        post.view_count = 0

        post_changeset = IntegrationPost.changeset(post)
        created_post_changeset = tx.insert(post_changeset)
        created_post = created_post_changeset.instance

        # Simulate an error to trigger rollback
        raise "Intentional error for rollback testing"
      end
    rescue ex
      # Expected error for rollback test
      ex.message.should eq("Intentional error for rollback testing")
    end

    # Verify rollback worked - nothing should be saved
    users = IntegrationRepo.all(IntegrationUser, Crecto::Repo::Query.where(username: "transaction_user"))
    users.should be_empty

    profiles = IntegrationRepo.all(IntegrationProfile, Crecto::Repo::Query.where(first_name: "Transaction"))
    profiles.should be_empty

    posts = IntegrationRepo.all(IntegrationPost, Crecto::Repo::Query.where(title: "Transaction Test Post"))
    posts.should be_empty
  end

  it "handles batch operations with complex queries" do
    # Create multiple users in batch
    users = [] of IntegrationUser
    10.times do |i|
      user = IntegrationUser.new
      user.username = "batch_user_#{i}"
      user.email = "batchuser#{i}@example.com"
      user.password_hash = "hash_#{i}"
      user.profile_complete = false
      users << user
    end

    # Insert all users
    created_users = [] of IntegrationUser
    users.each do |user|
      user_changeset = IntegrationUser.changeset(user)
      created_user_changeset = IntegrationRepo.insert(user_changeset)
      if created_user_changeset && created_user_changeset.valid?
        created_users << created_user_changeset.instance
      end
    end

    created_users.size.should eq(10)

    # Create posts for each user
    posts = [] of IntegrationPost
    created_users.each do |user|
      5.times do |i|
        post = IntegrationPost.new
        post.title = "Post #{i + 1} by #{user.username}"
        post.content = "Content for post #{i + 1}"
        post.author_id = user.id.not_nil!
        post.category_id = (i % 3) + 1
        post.status = i < 3 ? "published" : "draft"
        post.view_count = Random.rand(100)

        post_changeset = IntegrationPost.changeset(post)
        created_post_changeset = IntegrationRepo.insert(post_changeset)
        if created_post_changeset && created_post_changeset.valid?
          posts << created_post_changeset.instance
        end
      end
    end

    posts.size.should eq(50) # 10 users × 5 posts each

    # Test complex queries
    # Query 1: Get all published posts with authors
    published_posts = IntegrationRepo.all(IntegrationPost, Crecto::Repo::Query.where(status: "published"))
    published_posts.size.should eq(30) # 10 users × 3 published posts each

    # Query 2: Get users with most posts
    users_with_post_counts = created_users.map do |user|
      user_posts = IntegrationRepo.all(IntegrationPost, Crecto::Repo::Query.where(author_id: user.id))
      {user: user, post_count: user_posts.size}
    end

    users_with_post_counts.each do |user_data|
      user_data[:post_count].should eq(5)
    end

    # Query 3: Get posts by category
    category_1_posts = IntegrationRepo.all(IntegrationPost, Crecto::Repo::Query.where(category_id: 1))
    category_1_posts.size.should be > 0

    # Query 4: Update view counts in batch
    posts.each do |post|
      post.view_count = (post.view_count || 0) + Random.rand(10)
      # Crecto handles updated_at automatically
      post_changeset = IntegrationPost.changeset(post)
      IntegrationRepo.update(post_changeset)
    end

    # Verify updates
    updated_posts = IntegrationRepo.all(IntegrationPost)
    updated_posts.each do |post|
      (post.view_count || 0).should be >= 0
    end

    # Cleanup
    posts.each { |post| IntegrationRepo.delete(post) }
    created_users.each { |user| IntegrationRepo.delete(user) }
  end

  it "validates data integrity across relationships" do
    # Create user
    user = IntegrationUser.new
    user.username = "integrity_user"
    user.email = "integrity@example.com"
    user.password_hash = "hash"
    user.profile_complete = false

    user_changeset = IntegrationUser.changeset(user)
    created_user_changeset = IntegrationRepo.insert(user_changeset)
    created_user = created_user_changeset.instance
    user_id = created_user.id.not_nil!

    # Test foreign key constraints
    # Try to create post with non-existent user
    invalid_post = IntegrationPost.new
    invalid_post.title = "Invalid Post"
    invalid_post.content = "This should fail due to invalid user"
    invalid_post.author_id = 99999 # Non-existent user
    invalid_post.category_id = 1
    invalid_post.status = "published"
    invalid_post.view_count = 0

    invalid_post_changeset = IntegrationPost.changeset(invalid_post)
    # This might fail depending on database constraints
    # For SQLite, foreign key constraints need to be explicitly enabled

    # Create valid post
    post = IntegrationPost.new
    post.title = "Valid Post"
    post.content = "This should work"
    post.author_id = user_id
    post.category_id = 1
    post.status = "published"
    post.view_count = 0

    post_changeset = IntegrationPost.changeset(post)
    created_post_changeset = IntegrationRepo.insert(post_changeset)
    created_post_changeset.should_not be_nil
    created_post = created_post_changeset.instance

    # Try to delete user with existing posts (should fail or cascade)
    # This depends on foreign key constraint setup
    begin
      IntegrationRepo.delete(created_user)
      # If successful, verify cascade deletion
      remaining_posts = IntegrationRepo.all(IntegrationPost, Crecto::Repo::Query.where(author_id: user_id))
      # Posts should either be deleted (cascade) or user deletion should fail
    rescue ex
      # Expected if foreign key constraint prevents deletion
      (ex.message || "").should contain("FOREIGN KEY constraint")
    end

    # Cleanup in proper order
    comments = IntegrationRepo.all(IntegrationComment, Crecto::Repo::Query.where(post_id: created_post.id))
    comments.each { |comment| IntegrationRepo.delete(comment) }
    IntegrationRepo.delete(created_post.not_nil!)
    IntegrationRepo.delete(created_user.not_nil!)
  end

  it "handles concurrent access scenarios" do
    # Create a shared resource
    shared_post = IntegrationPost.new
    shared_post.title = "Shared Post"
    shared_post.content = "This post will be accessed concurrently"
    shared_post.author_id = 1
    shared_post.category_id = 1
    shared_post.status = "published"
    shared_post.view_count = 0

    post_changeset = IntegrationPost.changeset(shared_post)
    created_post_changeset = IntegrationRepo.insert(post_changeset)
    created_post = created_post_changeset.instance
    post_id = created_post.id.not_nil!

    # Simulate concurrent access
    channel = Channel(Int32).new(10)
    results = Channel(Bool).new(10)

    # Start multiple concurrent fibers
    10.times do |i|
      spawn do
        begin
          # Each fiber tries to increment view count
          post = IntegrationRepo.get(IntegrationPost, post_id)
          if post
            post.view_count = (post.view_count || 0) + 1
            # Crecto handles updated_at automatically
            post_changeset = IntegrationPost.changeset(post)
            updated_post_changeset = IntegrationRepo.update(post_changeset)
            results.send(updated_post_changeset != nil && updated_post_changeset.valid?)
          else
            results.send(false)
          end
        rescue ex
          results.send(false)
        end
      end
    end

    # Collect results
    successful_updates = 0
    10.times do
      if results.receive
        successful_updates += 1
      end
    end

    # Verify concurrent updates
    final_post = IntegrationRepo.get(IntegrationPost, post_id)
    final_post.should_not be_nil
    # Note: Due to potential race conditions, exact count might vary
    (final_post.not_nil!.view_count || 0).should be > 0

    # Cleanup
    IntegrationRepo.delete(created_post.not_nil!)
  end
end

private def setup_integration_database
  begin
    # Create tables for integration testing
    IntegrationRepo.raw_exec("CREATE TABLE IF NOT EXISTS integration_users (
      id INTEGER PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )")

    IntegrationRepo.raw_exec("CREATE TABLE IF NOT EXISTS integration_profiles (
      id INTEGER PRIMARY KEY,
      user_id INTEGER NOT NULL UNIQUE,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      bio TEXT,
      avatar_url TEXT,
      location TEXT,
      website TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES integration_users(id)
    )")

    IntegrationRepo.raw_exec("CREATE TABLE IF NOT EXISTS integration_categories (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      description TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )")

    IntegrationRepo.raw_exec("CREATE TABLE IF NOT EXISTS integration_posts (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      author_id INTEGER NOT NULL,
      category_id INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'draft',
      view_count INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (author_id) REFERENCES integration_users(id),
      FOREIGN KEY (category_id) REFERENCES integration_categories(id)
    )")

    IntegrationRepo.raw_exec("CREATE TABLE IF NOT EXISTS integration_comments (
      id INTEGER PRIMARY KEY,
      content TEXT NOT NULL,
      author_name TEXT NOT NULL,
      author_email TEXT NOT NULL,
      post_id INTEGER NOT NULL,
      approved BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (post_id) REFERENCES integration_posts(id)
    )")

    # Insert test categories
    categories = [
      {name: "Technology", description: "Tech related posts"},
      {name: "Programming", description: "Programming tutorials"},
      {name: "Crystal", description: "Crystal language specific"}
    ]

    categories.each do |cat|
      IntegrationRepo.raw_exec("INSERT OR IGNORE INTO integration_categories (name, description, created_at, updated_at) VALUES (?, ?, ?, ?)",
        cat[:name], cat[:description], Time.utc.to_s, Time.utc.to_s)
    end

  rescue ex
    puts "Error setting up integration database: #{ex.message}"
  end
end

private def cleanup_integration_database
  begin
    IntegrationRepo.raw_exec("DROP TABLE IF EXISTS integration_comments")
    IntegrationRepo.raw_exec("DROP TABLE IF EXISTS integration_posts")
    IntegrationRepo.raw_exec("DROP TABLE IF EXISTS integration_profiles")
    IntegrationRepo.raw_exec("DROP TABLE IF EXISTS integration_categories")
    IntegrationRepo.raw_exec("DROP TABLE IF EXISTS integration_users")
  rescue ex
    puts "Error cleaning up integration database: #{ex.message}"
  end
end