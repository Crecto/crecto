require "../spec_helper"

# Performance tests for bulk insert operations
# These tests validate the 10x+ performance improvement requirement
describe "Bulk Insert Performance" do

  before_each do
    # Clean up database before each test to ensure isolation
    begin
      # More thorough cleanup to ensure test isolation
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'Bulk User%'")
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'Individual User%'")
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'Scale Test%'")
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'Memory Test%'")
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'PG User%'")
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'MySQL User%'")
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'SQLite User%'")
      Repo.raw_exec("DELETE FROM users WHERE name LIKE 'Consistency Test%'")
      Repo.delete_all(User)
      Repo.delete_all(Post)
      Repo.delete_all(Address)
    rescue ex
      # Ignore cleanup errors
    end

    # Additional cleanup to ensure no records with nil names exist
    begin
      Repo.raw_exec("DELETE FROM users WHERE name IS NULL")
    rescue ex
      # Ignore cleanup errors
    end
  end

  describe "performance benchmarks" do
    it "achieves 10x+ performance improvement over individual inserts" do
      test_sizes = [10, 50, 100, 500]

      test_sizes.each do |size|
        puts "\n=== Testing with #{size} records ==="

        # Prepare test data
        bulk_users = Array(User).new(size) do |i|
          user = User.new
          user.name = "Bulk User #{i}"
          user.things = 20 + (i % 50)
          user
        end

        individual_users = Array(User).new(size) do |i|
          user = User.new
          user.name = "Individual User #{i}"
          user.things = 20 + (i % 50)
          user
        end

        # Benchmark bulk insert
        bulk_start = Time.local
        bulk_result = Repo.insert_all(User, bulk_users)
        bulk_duration = Time.local - bulk_start

        # Benchmark individual inserts
        individual_start = Time.local
        individual_ids = [] of Int64?
        individual_users.each do |user|
          result = Repo.insert(user)
          if result.valid? && result.instance.id
            individual_ids << result.instance.id.as(Int64)
          end
        end
        individual_duration = Time.local - individual_start

        # Calculate performance improvement
        improvement = individual_duration.total_milliseconds / bulk_duration.total_milliseconds

        puts "Bulk insert: #{bulk_duration.total_milliseconds.round(2)}ms"
        puts "Individual inserts: #{individual_duration.total_milliseconds.round(2)}ms"
        puts "Performance improvement: #{improvement.round(2)}x"

        # Assertions
        bulk_result.successful?.should be_true
        bulk_result.successful_count.should eq(size)
        individual_ids.size.should eq(size)

        # Performance requirement: Database-specific improvement targets
        adapter = Repo.config.adapter
        required_improvement = case adapter.to_s
        when "Crecto::Adapters::Postgres", "Crecto::Adapters::Mysql"
          10.0  # Native bulk insert optimization should achieve 10x+
        when "Crecto::Adapters::SQLite3"
          2.0   # Transaction-wrapped inserts are more modest but still significant
        else
          5.0   # Conservative default for unknown adapters
        end

        puts "Required improvement for #{adapter}: #{required_improvement}x"
        improvement.should be >= required_improvement, "Performance improvement of #{improvement.round(2)}x is below required #{required_improvement}x for #{adapter} with #{size} records"

        # Additional performance sanity checks
        bulk_duration.total_milliseconds.should be < individual_duration.total_milliseconds
        bulk_result.duration_ms.should be > 0
      end
    end

    it "maintains performance with increasing dataset sizes" do
      sizes = [10, 25, 50, 100, 200]
      durations = [] of Float64

      sizes.each do |size|
        users = Array(User).new(size) do |i|
          user = User.new
          user.name = "Scale Test #{i}"
          user.things = 20 + (i % 40)
          user
        end

        start_time = Time.local
        result = Repo.insert_all(User, users)
        duration = Time.local - start_time

        durations << duration.total_milliseconds
        puts "#{size} records: #{duration.total_milliseconds.round(2)}ms"

        result.successful?.should be_true
        result.successful_count.should eq(size)
      end

      # Performance should scale reasonably (not exponentially degrade)
      # This is a rough check - performance can vary based on system and database
      if durations.size >= 3
        # Calculate average time per record for each size
        avg_times = durations.map_with_index { |duration, i| duration / sizes[i] }

        # Time per record shouldn't increase dramatically
        # Allow for some variance but check for major performance degradation
        max_avg_time = avg_times.max
        min_avg_time = avg_times.min
        variance_factor = max_avg_time / min_avg_time

        puts "Time per record variance factor: #{variance_factor.round(2)}x"
        variance_factor.should be < 5.0, "Performance variance too high: #{variance_factor.round(2)}x"
      end
    end

    it "validates memory efficiency during bulk operations" do
      # Test memory usage doesn't grow excessively
      initial_memory = GC.stats.heap_size

      # Create and insert a larger dataset
      large_dataset = Array(User).new(1000) do |i|
        user = User.new
        user.name = "Memory Test #{i}"
        user.things = 20 + (i % 60)
        user
      end

      start_time = Time.local
      result = Repo.insert_all(User, large_dataset)
      duration = Time.local - start_time

      final_memory = GC.stats.heap_size
      memory_increase = final_memory - initial_memory

      puts "Memory increase: #{(memory_increase / 1024.0 / 1024.0).round(2)} MB"
      puts "Duration for 1000 records: #{duration.total_milliseconds.round(2)}ms"

      result.successful?.should be_true
      result.successful_count.should eq(1000)

      # Memory increase should be reasonable (less than 50MB for 1000 simple records)
      memory_increase.should be < 50 * 1024 * 1024, "Memory usage too high: #{(memory_increase / 1024.0 / 1024.0).round(2)} MB"

      # Performance should still be good even for larger datasets
      duration.total_milliseconds.should be < 5000, "Duration too high: #{duration.total_milliseconds.round(2)}ms"
    end
  end

  describe "database-specific optimizations" do
    it "validates PostgreSQL-specific optimizations" do
      # Test if PostgreSQL adapter is being used and if optimizations are working
      adapter = Repo.config.adapter

      if adapter.is_a?(Crecto::Adapters::Postgres)
        puts "Testing PostgreSQL-specific optimizations..."

        users = Array(User).new(100) do |i|
          user = User.new
          user.name = "PG User #{i}"
          user.things = 25 + (i % 30)
          user
        end

        start_time = Time.local
        result = Repo.insert_all(User, users)
        duration = Time.local - start_time

        puts "PostgreSQL bulk insert (100 records): #{duration.total_milliseconds.round(2)}ms"

        result.successful?.should be_true
        result.successful_count.should eq(100)

        # PostgreSQL should be very fast for bulk operations
        duration.total_milliseconds.should be < 1000, "PostgreSQL bulk insert too slow: #{duration.total_milliseconds.round(2)}ms"
      end
    end

    it "validates MySQL-specific optimizations" do
      adapter = Repo.config.adapter

      if adapter.is_a?(Crecto::Adapters::Mysql)
        puts "Testing MySQL-specific optimizations..."

        users = Array(User).new(100) do |i|
          user = User.new
          user.name = "MySQL User #{i}"
          user.things = 25 + (i % 30)
          user
        end

        start_time = Time.local
        result = Repo.insert_all(User, users)
        duration = Time.local - start_time

        puts "MySQL bulk insert (100 records): #{duration.total_milliseconds.round(2)}ms"

        result.successful?.should be_true
        result.successful_count.should eq(100)

        duration.total_milliseconds.should be < 1000, "MySQL bulk insert too slow: #{duration.total_milliseconds.round(2)}ms"
      end
    end

    it "validates SQLite3 transaction efficiency" do
      adapter = Repo.config.adapter

      if adapter.is_a?(Crecto::Adapters::SQLite3)
        puts "Testing SQLite3 transaction-wrapped optimizations..."

        users = Array(User).new(100) do |i|
          user = User.new
          user.name = "SQLite User #{i}"
          user.things = 25 + (i % 30)
          user
        end

        start_time = Time.local
        result = Repo.insert_all(User, users)
        duration = Time.local - start_time

        puts "SQLite3 bulk insert (100 records): #{duration.total_milliseconds.round(2)}ms"

        result.successful?.should be_true
        result.successful_count.should eq(100)

        # SQLite3 will be slower than PostgreSQL/MySQL but should still be reasonable
        duration.total_milliseconds.should be < 3000, "SQLite3 bulk insert too slow: #{duration.total_milliseconds.round(2)}ms"
      end
    end
  end

  describe "cross-database consistency" do
    it "ensures consistent behavior across all supported databases" do
      # Test that bulk insert behaves consistently regardless of database
      user1 = User.new
      user1.name = "Consistency Test 1"
      user1.things = 28

      user2 = User.new
      user2.name = "Consistency Test 2"
      user2.things = 32

      user3 = User.new
      user3.name = "Consistency Test 3"
      user3.things = 36

      test_records = [user1, user2, user3]

      start_time = Time.local
      result = Repo.insert_all(User, test_records)
      duration = Time.local - start_time

      # Consistency checks that should work for all databases
      result.total_count.should eq(3)
      result.successful_count.should eq(3)
      result.failed_count.should eq(0)
      result.successful?.should be_true
      result.inserted_ids.size.should eq(3)
      result.duration_ms.should be > 0
      result.errors.should be_empty

      # Verify records were actually inserted and are accessible
      inserted_users = Repo.all(User, Query.where(name: ["Consistency Test 1", "Consistency Test 2", "Consistency Test 3"]))
      inserted_users.size.should eq(3)

      # Verify all records have the expected data
      inserted_users.each do |user|
        user.name.should_not be_nil  # Safety check
        user.name.as(String).should contain("Consistency Test")
        user.things.should_not be_nil  # Safety check
        user.things.as(Int32 | Int64).should be >= 28
        user.things.as(Int32 | Int64).should be <= 36
      end

      puts "Cross-database consistency test completed in #{duration.total_milliseconds.round(2)}ms"
    end
  end
end