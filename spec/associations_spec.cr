require "./spec_helper"

describe "Associations IndexError Safety" do
  describe "belongs_to associations" do
    it "should not raise IndexError when accessing empty associations" do
      # Create a post without a user
      post = Post.new
      post = Repo.insert(post).instance

      # Should not raise IndexError when accessing belongs_to associations
      # This tests the fix for issues #133, #195
      post.user?.should eq(nil)

      # Access through the association system should also be safe
      Post.klass_for_association(:user).should eq(User)
      Post.foreign_key_for_association(:user).should eq(:user_id)
    end

    it "should safely handle association setting with empty arrays" do
      post = Post.new
      post = Repo.insert(post).instance

      # Attempting to set association with empty array should not raise IndexError
      # This tests bounds checking in belongs_to.cr:48
      # Should set association to nil safely instead of crashing
      empty_array = [] of Crecto::Model
      Post.set_value_for_association(:user, post, empty_array)
      post.user?.should eq(nil)
    end
  end

  describe "has_many associations" do
    it "should not raise IndexError when accessing empty has_many associations" do
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Should not raise IndexError when accessing has_many associations
      # This tests the fix for issues #133, #195
      user.posts?.should eq(nil)
      user.addresses?.should eq(nil)

      # After preloading with no results, should return empty arrays safely
      users = Repo.all(User, Query.where(id: user.id).preload(:posts))
      users[0].posts.should be_a(Array(Post))
      users[0].posts.size.should eq(0)
    end

    it "should safely handle has_many association operations with empty collections" do
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Test association operations with empty collections
      # This tests bounds checking in has_many.cr:54-55
      empty_posts = [] of Post

      # Should handle empty array operations safely
      user.posts = empty_posts
      user.posts.should be_a(Array(Post))
      user.posts.size.should eq(0)
    end
  end

  describe "has_one associations" do
    it "should not raise IndexError when accessing unset has_one associations" do
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Should not raise IndexError when accessing has_one associations
      # This tests the fix for issues #133, #195
      user.post?.should eq(nil)

      # After preloading with no results, should return nil safely
      users = Repo.all(User, Query.where(id: user.id).preload(:post))
      users[0].post?.should eq(nil)
    end

    it "should safely handle has_one association operations with nil values" do
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Test association operations with nil values
      # This tests bounds checking in has_one associations
      user.post = nil
      user.post?.should eq(nil)
    end
  end

  describe "association queries with no results" do
    it "should safely handle association queries that return no results" do
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Association queries should handle empty results safely
      # This tests bounds checking in associations.cr:18-34
      posts = Repo.get_association(user, :posts)
      posts.should be_a(Array(Post))
      posts.as(Array).size.should eq(0)

      post_for_user = Repo.get_association(user, :post)
      post_for_user.should eq(nil)
    end

    it "should safely handle foreign key queries for non-existent associations" do
      # Test foreign key value queries for non-existent associations
      # This tests bounds checking in associations.cr:34
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Should not raise IndexError when querying foreign keys for non-existent associations
      foreign_key = User.foreign_key_value_for_association(:posts, user)
      foreign_key.should eq(user.id)
    end
  end

  describe "association loading with missing data" do
    it "should safely preload associations when no related records exist" do
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Should not raise IndexError during preloading
      # This tests the association loading system with empty results
      users = Repo.all(User, Query.where(id: user.id).preload([:posts, :addresses, :post]))

      users.size.should eq(1)
      users[0].posts.should be_a(Array(Post))
      users[0].posts.size.should eq(0)
      users[0].addresses.should be_a(Array(Address))
      users[0].addresses.size.should eq(0)
      users[0].post?.should eq(nil)
    end
  end

  describe "association type safety" do
    it "should safely handle association type queries" do
      # Test association type queries with bounds checking
      # This tests associations.cr:46 with safe array access
      association_type = User.association_type_for_association(:posts)
      association_type.should eq(:has_many)

      association_type = User.association_type_for_association(:post)
      association_type.should eq(:has_one)
    end

    it "should safely handle through association queries" do
      # Test through association queries with bounds checking
      # This tests associations.cr:52 with safe array access
      through_key = User.through_key_for_association(:projects)
      through_key.should eq(:user_projects)
    end
  end

  describe "complex association scenarios" do
    it "should handle nested associations safely" do
      # Create a complex scenario with nested associations
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      post = Post.new
      post.user = user
      post = Repo.insert(post).instance

      # Test nested association access - need to reload association after insert
      # This should not raise IndexError due to bounds checking
      post = Repo.get!(Post, post.id, Query.preload(:user))
      post.user?.should_not be_nil
      post.user.as(User).name.should eq("Test User")
    end

    it "should handle association cleanup safely" do
      # Test association cleanup scenarios
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      post = Post.new
      post.user = user
      post = Repo.insert(post).instance

      # Delete the user and test association access
      Repo.delete(user)

      # Association access should handle missing related records safely
      post = Repo.get!(Post, post.id)
      post.user_id.should_not be_nil

      # Preloading should handle missing associations safely
      posts = Repo.all(Post, Query.where(id: post.id).preload(:user))
      posts[0].user?.should eq(nil)  # User was deleted
    end
  end

  describe "association bounds checking" do
    it "should safely handle association method calls on empty collections" do
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Test all association methods that use array access
      # These should not raise IndexError due to bounds checking
      User.klass_for_association(:posts).should eq(Post)
      User.foreign_key_for_association(:posts).should eq(:user_id)
      User.association_type_for_association(:posts).should eq(:has_many)
      User.through_key_for_association(:projects).should eq(:user_projects)
    end

    it "should handle safe array access in association setters" do
      # Test the specific array access patterns that caused IndexError
      user = User.new
      user.name = "Test User"
      user = Repo.insert(user).instance

      # Test setting associations through various methods
      # This should trigger the bounds checking code paths
      empty_array = [] of Post
      user.posts = empty_array

      # Verify the association was set safely
      user.posts.should be_a(Array(Post))
      user.posts.size.should eq(0)
    end
  end
end