require "../spec_helper"

describe Repo do
  before_each do
    # Clean up database before each test to ensure isolation
    begin
      Repo.delete_all(User)
      Repo.delete_all(UserRequired)
      Repo.delete_all(Post)
      Repo.delete_all(Address)
      Repo.delete_all(Project)
      Repo.delete_all(UserProject)
    rescue ex
      # Ignore cleanup errors
    end
  end
  describe "insert_all" do
    describe "basic functionality" do
      it "inserts multiple records with model instances" do
        user1 = User.new
        user1.name = "Alice"
        user1.things = 25

        user2 = User.new
        user2.name = "Bob"
        user2.things = 30

        user3 = User.new
        user3.name = "Charlie"
        user3.things = 35

        users = [user1, user2, user3]
        result = Repo.insert_all(User, users)

        result.should be_a(Crecto::BulkResult)
        result.total_count.should eq(3)
        result.successful_count.should eq(3)
        result.failed_count.should eq(0)
        result.successful?.should be_true
        result.inserted_ids.size.should eq(3)
        result.duration_ms.should be > 0

        # Verify records were actually inserted
        inserted_users = Repo.all(User, Query.where(name: ["Alice", "Bob", "Charlie"]))
        inserted_users.size.should eq(3)
      end

      it "inserts multiple records with hash data" do
        user_data = [
          {"name" => "Dave", "things" => 28},
          {"name" => "Eve", "things" => 32}
        ]

        result = Repo.insert_all(User, user_data)

        result.total_count.should eq(2)
        result.successful_count.should eq(2)
        result.failed_count.should eq(0)
        result.successful?.should be_true
        result.inserted_ids.size.should eq(2)
      end

      it "inserts multiple records with NamedTuple data" do
        user_data = [
          {name: "Frank", things: 27},
          {name: "Grace", things: 33}
        ]

        result = Repo.insert_all(User, user_data)

        result.total_count.should eq(2)
        result.successful_count.should eq(2)
        result.failed_count.should eq(0)
        result.successful?.should be_true
        result.inserted_ids.size.should eq(2)
      end

      it "handles empty arrays gracefully" do
        expect_raises(ArgumentError, "Records array cannot be empty") do
          Repo.insert_all(User, [] of User)
        end
      end
    end

    describe "validation handling" do
      it "fails records with invalid data" do
        user1 = UserRequired.new
        user1.name = "Valid User"
        user1.age = 25
        user1.is_admin = false

        user2 = UserRequired.new
        user2.name = "Invalid User"
        # user2.age is nil - should fail validation
        # user2.is_admin is nil - should fail validation

        users = [user1, user2]

        result = Repo.insert_all(UserRequired, users)

        result.total_count.should eq(2)
        result.successful_count.should eq(1)
        result.failed_count.should eq(1)
        result.successful?.should be_false
        result.partial_success?.should be_true
        result.errors.size.should eq(1)
        result.errors.first.index.should eq(1)
        result.errors.first.error_class.should contain("ValidationError")
      end

      it "provides detailed error information" do
        user1 = UserRequired.new
        user1.name = "Another Valid User"
        user1.age = 30
        user1.is_admin = false

        user2 = UserRequired.new
        user2.name = "User with missing fields"
        # user2.age is nil - should fail validation
        # user2.is_admin is nil - should fail validation

        users = [user1, user2]

        result = Repo.insert_all(UserRequired, users)

        error = result.errors.first
        error.index.should eq(1)
        error.error_message.should_not be_empty
        error.error_class.should_not be_empty
        error.timestamp.should be_a(Time)
        error.record_hash.should_not be_nil
      end
    end

    describe "transaction handling" do
      it "handles atomic operations correctly" do
        # This test depends on the database adapter's behavior
        # PostgreSQL and MySQL should handle multi-row inserts atomically
        # SQLite3 uses transaction-wrapped individual inserts

        user1 = User.new
        user1.name = "Transaction Test 1"
        user1.things = 25

        user2 = User.new
        user2.name = "Transaction Test 2"
        user2.things = 30

        users = [user1, user2]
        result = Repo.insert_all(User, users)

        # Both should succeed in normal conditions
        result.successful_count.should eq(2)
        result.failed_count.should eq(0)

        # Verify atomicity - either all or nothing should be inserted
        count = Repo.aggregate(User, :count, :id,
          Query.where("name LIKE ?", "Transaction Test%"))
        count.should eq(2)
      end

      it "works within existing transactions" do
        Repo.transaction! do |tx|
          user1 = User.new
          user1.name = "Transaction User 1"
          user1.things = 40

          user2 = User.new
          user2.name = "Transaction User 2"
          user2.things = 45

          users = [user1, user2]
          result = tx.insert_all(User, users)
          result.successful?.should be_true
          result.successful_count.should eq(2)
        end

        # Verify records were committed
        count = Repo.aggregate(User, :count, :id,
          Query.where("name LIKE ?", "Transaction User%"))
        count.should eq(2)
      end
    end

    describe "performance characteristics" do
      it "handles larger datasets efficiently" do
        # Create a reasonable number of test records
        users = Array(User).new(50) do |i|
          user = User.new
          user.name = "Perf User #{i}"
          user.things = 20 + (i % 50)
          user
        end

        start_time = Time.local
        result = Repo.insert_all(User, users)
        duration = Time.local - start_time

        result.successful?.should be_true
        result.successful_count.should eq(50)
        result.duration_ms.should be > 0

        # Should complete in reasonable time (adjust threshold as needed)
        duration.total_seconds.should be < 5.0

        # Verify all records were inserted
        count = Repo.aggregate(User, :count, :id,
          Query.where("name LIKE ?", "Perf User%"))
        count.should eq(50)
      end
    end

    describe "error recovery" do
      it "handles partial failures gracefully" do
        # Mix valid and invalid records
        user1 = UserRequired.new
        user1.name = "Valid 1"
        user1.age = 25
        user1.is_admin = false

        user2 = UserRequired.new
        user2.name = "Invalid 1"
        # user2.age is nil - should fail validation
        # user2.is_admin is nil - should fail validation

        user3 = UserRequired.new
        user3.name = "Valid 2"
        user3.age = 30
        user3.is_admin = false

        user4 = UserRequired.new
        user4.name = "Invalid 2"
        # user4.age is nil - should fail validation
        # user4.is_admin is nil - should fail validation

        user5 = UserRequired.new
        user5.name = "Valid 3"
        user5.age = 35
        user5.is_admin = false

        users = [user1, user2, user3, user4, user5]

        result = Repo.insert_all(UserRequired, users)

        result.total_count.should eq(5)
        result.successful_count.should eq(3)
        result.failed_count.should eq(2)
        result.partial_success?.should be_true
        result.successful?.should be_false
        result.errors.size.should eq(2)

        # Verify error indices are correct
        failed_indices = result.errors.map(&.index).sort
        failed_indices.should eq([1, 3])
      end

      it "provides recovery guidance for common errors" do
        # This tests the error classification logic
        user1 = UserRequired.new
        user1.name = "Test User"
        user1.age = 25
        user1.is_admin = false

        user2 = UserRequired.new
        user2.name = "Invalid User"
        # user2.age is nil - should fail validation
        # user2.is_admin is nil - should fail validation

        users = [user1, user2]

        result = Repo.insert_all(UserRequired, users)
        error = result.errors.first

        # Check error classification
        error.error_class.should_not be_empty
        error.error_message.should_not be_empty

        # Should be able to determine error type
        error.data_type_error?.should be_true  # Validation errors are data type errors
        error.constraint_violation?.should be_false
        error.connection_error?.should be_false
      end
    end

    describe "insert_all! (strict version)" do
      it "raises exception on any failure" do
        user1 = UserRequired.new
        user1.name = "Valid User"
        user1.age = 25
        user1.is_admin = false

        user2 = UserRequired.new
        user2.name = "Invalid User"
        # user2.age is nil - should fail validation
        # user2.is_admin is nil - should fail validation

        users = [user1, user2]

        expect_raises(Exception) do
          Repo.insert_all!(UserRequired, users)
        end
      end

      it "succeeds when all records are valid" do
        user1 = UserRequired.new
        user1.name = "Strict User 1"
        user1.age = 22
        user1.is_admin = false

        user2 = UserRequired.new
        user2.name = "Strict User 2"
        user2.age = 28
        user2.is_admin = false

        users = [user1, user2]

        result = Repo.insert_all!(UserRequired, users)
        result.successful?.should be_true
        result.successful_count.should eq(2)
      end
    end
  end

  describe "bulk insert integration" do
    it "works with models that have associations" do
      # Test with Post model which has a belongs_to relationship
      post1 = Post.new
      post2 = Post.new

      result = Repo.insert_all(Post, [post1, post2])
      result.successful?.should be_true
      result.successful_count.should eq(2)
    end

    it "handles different data types correctly" do
      # Test with various data types using User model
      user1 = User.new
      user1.name = "User 1"
      user1.things = 100
      user1.yep = true

      user2 = User.new
      user2.name = "User 2"
      user2.things = 200
      user2.yep = false

      result = Repo.insert_all(User, [user1, user2])
      result.successful?.should be_true
      result.successful_count.should eq(2)
    end
  end
end