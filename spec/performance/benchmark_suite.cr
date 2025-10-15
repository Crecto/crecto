require "spec"
require "./spec_helper"
require "benchmark"
require "./performance_models"

describe Crecto::Performance do
  describe "Performance Benchmarking Suite" do
    before_all do
      setup_performance_database
      seed_performance_data
    end

    after_all do
      cleanup_performance_database
      save_benchmark_results
    end

    @@benchmark_results = Hash(String, BenchmarkResult).new

    struct BenchmarkResult
      property name : String
      property operation_count : Int32
      property total_time : Time::Span
      property average_time : Float64
      property min_time : Float64
      property max_time : Float64
      property operations_per_second : Float64
      property memory_usage_mb : Float64?
      property timestamp : Time

      def initialize(@name, @operation_count, @total_time, @average_time, @min_time, @max_time, @operations_per_second, @memory_usage_mb = nil)
        @timestamp = Time.utc
      end

      def to_s
        "#{@name}: #{@operations_per_second.round(2)} ops/sec (avg: #{@average_time.round(3)}ms, min: #{@min_time.round(3)}ms, max: #{@max_time.round(3)}ms)"
      end
    end

    it "establishes baseline CRUD performance benchmarks" do
      puts "\n📈 Establishing CRUD Performance Benchmarks"

      # Benchmark Insert operations
      insert_result = benchmark_crud_operation("Insert", ->{create_benchmark_user}) do
        create_benchmark_user
      end
      @@benchmark_results["crud_insert"] = insert_result
      puts "Insert: #{insert_result.operations_per_second.round(2)} ops/sec"

      # Benchmark Read operations
      read_result = benchmark_crud_operation("Read", ->{read_benchmark_user(1)}) do
        read_benchmark_user(Random.rand(1000) + 1)
      end
      @@benchmark_results["crud_read"] = read_result
      puts "Read: #{read_result.operations_per_second.round(2)} ops/sec"

      # Benchmark Update operations
      update_result = benchmark_crud_operation("Update", ->{update_benchmark_user(1)}) do
        update_benchmark_user(Random.rand(1000) + 1)
      end
      @@benchmark_results["crud_update"] = update_result
      puts "Update: #{update_result.operations_per_second.round(2)} ops/sec"

      # Benchmark Delete operations
      delete_result = benchmark_crud_operation("Delete", ->{delete_benchmark_user(1)}) do
        delete_benchmark_user(Random.rand(1000) + 1)
      end
      @@benchmark_results["crud_delete"] = delete_result
      puts "Delete: #{delete_result.operations_per_second.round(2)} ops/sec"

      # Performance assertions
      insert_result.operations_per_second.should be > 1000 # Should handle at least 1000 inserts/sec
      read_result.operations_per_second.should be > 5000 # Should handle at least 5000 reads/sec
      update_result.operations_per_second.should be > 2000 # Should handle at least 2000 updates/sec
      delete_result.operations_per_second.should be > 2000 # Should handle at least 2000 deletes/sec
    end

    it "benchmarks complex query performance" do
      puts "\n🔍 Establishing Query Performance Benchmarks"

      # Simple query benchmark
      simple_query_result = benchmark_query_operation("Simple Query", 1000) do
        PerformanceRepo.all(PerformanceUser, Crecto::Repo::Query.where("active = ?", true).limit(10))
      end
      @@benchmark_results["query_simple"] = simple_query_result
      puts "Simple Query: #{simple_query_result.operations_per_second.round(2)} queries/sec"

      # Complex query benchmark with joins
      complex_query_result = benchmark_query_operation("Complex Query with Joins", 500) do
        PerformanceRepo.all(PerformanceUser) do |query|
          query.join(:performance_posts, :user_id, :id)
               .where("performance_posts.published = ? AND performance_users.age > ?", true, 25)
               .limit(5)
        end
      end
      @@benchmark_results["query_complex"] = complex_query_result
      puts "Complex Query: #{complex_query_result.operations_per_second.round(2)} queries/sec"

      # Aggregation query benchmark
      aggregation_result = benchmark_query_operation("Aggregation Query", 200) do
        PerformanceRepo.aggregate(:performance_users, :count, "active = ?", true)
      end
      @@benchmark_results["query_aggregation"] = aggregation_result
      puts "Aggregation Query: #{aggregation_result.operations_per_second.round(2)} queries/sec"

      # Performance assertions
      simple_query_result.operations_per_second.should be > 1000
      complex_query_result.operations_per_second.should be > 100
      aggregation_result.operations_per_second.should be > 500
    end

    it "benchmarks association loading performance" do
      puts "\n🔗 Establishing Association Loading Benchmarks"

      # Lazy loading benchmark
      lazy_loading_result = benchmark_association_operation("Lazy Loading", 1000) do
        users = PerformanceRepo.all(PerformanceUser, Crecto::Repo::Query.limit(10))
        users.each do |user|
          posts = PerformanceRepo.all(PerformancePost, Crecto::Repo::Query.where(user_id: user.id))
        end
      end
      @@benchmark_results["association_lazy"] = lazy_loading_result
      puts "Lazy Loading: #{lazy_loading_result.operations_per_second.round(2)} operations/sec"

      # Eager loading simulation
      eager_loading_result = benchmark_association_operation("Eager Loading", 1000) do
        users = PerformanceRepo.all(PerformanceUser, Crecto::Repo::Query.limit(10))
        user_ids = users.map(&.id).compact
        posts = PerformanceRepo.all(PerformancePost, Crecto::Repo::Query.where(user_id: user_ids)) if user_ids.any?
      end
      @@benchmark_results["association_eager"] = eager_loading_result
      puts "Eager Loading: #{eager_loading_result.operations_per_second.round(2)} operations/sec"

      # Nested association benchmark
      nested_association_result = benchmark_association_operation("Nested Associations", 500) do
        users = PerformanceRepo.all(PerformanceUser, Crecto::Repo::Query.limit(5))
        users.each do |user|
          posts = PerformanceRepo.all(PerformancePost, Crecto::Repo::Query.where(user_id: user.id))
          post_ids = posts.map(&.id).compact
          if post_ids.any?
            comments = PerformanceRepo.all(PerformanceComment, Crecto::Repo::Query.where(post_id: post_ids))
          end
        end
      end
      @@benchmark_results["association_nested"] = nested_association_result
      puts "Nested Associations: #{nested_association_result.operations_per_second.round(2)} operations/sec"

      # Performance assertions
      lazy_loading_result.operations_per_second.should be > 50
      eager_loading_result.operations_per_second.should be > 100
      nested_association_result.operations_per_second.should be > 25
    end

    it "benchmarks transaction performance" do
      puts "\n💳 Establishing Transaction Performance Benchmarks"

      # Single transaction benchmark
      single_transaction_result = benchmark_transaction_operation("Single Transaction", 100) do
        PerformanceRepo.transaction do |tx|
          user = create_benchmark_user_in_tx(tx)
          if user
            post = create_benchmark_post_in_tx(user.id.not_nil!, tx)
            if post
              create_benchmark_comment_in_tx(post.id.not_nil!, tx)
            end
          end
        end
      end
      @@benchmark_results["transaction_single"] = single_transaction_result
      puts "Single Transaction: #{single_transaction_result.operations_per_second.round(2)} transactions/sec"

      # Batch operations in transaction
      batch_transaction_result = benchmark_transaction_operation("Batch Transaction", 50) do
        PerformanceRepo.transaction do |tx|
          10.times do |i|
            user = create_benchmark_user_in_tx(tx)
            if user
              3.times do |j|
                create_benchmark_post_in_tx(user.id.not_nil!, tx)
              end
            end
          end
        end
      end
      @@benchmark_results["transaction_batch"] = batch_transaction_result
      puts "Batch Transaction: #{batch_transaction_result.operations_per_second.round(2)} transactions/sec"

      # Performance assertions
      single_transaction_result.operations_per_second.should be > 10
      batch_transaction_result.operations_per_second.should be > 5
    end

    it "benchmarks memory usage and resource consumption" do
      puts "\n🧠 Establishing Memory Usage Benchmarks"

      # Get initial memory usage
      initial_memory = get_memory_usage_mb

      # Memory usage during large operations
      memory_result = benchmark_memory_operation("Large Dataset Processing", 1000) do
        users = PerformanceRepo.all(PerformanceUser, Crecto::Repo::Query.limit(1000))
        processed_users = users.map do |user|
          {
            id: user.id,
            name: user.name,
            post_count: PerformanceRepo.aggregate(PerformancePost, :count, "user_id = ?", user.id),
            age_group: user.age >= 30 ? "senior" : "junior"
          }
        end
        processed_users.size
      end
      @@benchmark_results["memory_large_dataset"] = memory_result

      final_memory = get_memory_usage_mb
      memory_increase = final_memory - initial_memory

      puts "Memory Usage:"
      puts "  Initial: #{initial_memory.round(2)}MB"
      puts "  Final: #{final_memory.round(2)}MB"
      puts "  Increase: #{memory_increase.round(2)}MB"
      puts "  Operations: #{memory_result.operations_per_second.round(2)} ops/sec"

      # Memory efficiency assertions
      memory_increase.should be < 100 # Should use less than 100MB for 1000 user processing
      memory_result.operations_per_second.should be > 10
    end

    it "establishes regression detection baselines" do
      puts "\n📊 Creating Performance Baseline for Regression Detection"

      baseline_data = {
        "crud_insert" => @@benchmark_results["crud_insert"]?.try(&.operations_per_second) || 0,
        "crud_read" => @@benchmark_results["crud_read"]?.try(&.operations_per_second) || 0,
        "crud_update" => @@benchmark_results["crud_update"]?.try(&.operations_per_second) || 0,
        "crud_delete" => @@benchmark_results["crud_delete"]?.try(&.operations_per_second) || 0,
        "query_simple" => @@benchmark_results["query_simple"]?.try(&.operations_per_second) || 0,
        "query_complex" => @@benchmark_results["query_complex"]?.try(&.operations_per_second) || 0,
        "association_lazy" => @@benchmark_results["association_lazy"]?.try(&.operations_per_second) || 0,
        "association_eager" => @@benchmark_results["association_eager"]?.try(&.operations_per_second) || 0,
        "transaction_single" => @@benchmark_results["transaction_single"]?.try(&.operations_per_second) || 0,
        "memory_large_dataset" => @@benchmark_results["memory_large_dataset"]?.try(&.operations_per_second) || 0
      }

      # Save baseline for future regression detection
      File.write("spec/performance/baseline_#{Time.utc.to_s("%Y%m%d_%H%M%S")}.json", baseline_data.to_json)

      puts "Performance Baselines Established:"
      baseline_data.each do |operation, ops_per_sec|
        puts "  #{operation}: #{ops_per_sec.round(2)} ops/sec"
      end

      # Verify all critical operations meet minimum performance thresholds
      baseline_data["crud_insert"].should be > 1000
      baseline_data["crud_read"].should be > 5000
      baseline_data["query_simple"].should be > 1000
      baseline_data["association_lazy"].should be > 50
    end
  end

  private def benchmark_crud_operation(name : String, operation : Proc) : BenchmarkResult
    operation_count = 1000
    times = [] of Float64

    # Warmup
    10.times { operation.call }

    # Benchmark
    operation_count.times do
      time = Benchmark.realtime do
        operation.call
      end
      times << time.total_milliseconds
    end

    total_time = times.sum
    average_time = total_time / operation_count
    min_time = times.min
    max_time = times.max
    ops_per_sec = operation_count.to_f / (total_time / 1000.0)

    BenchmarkResult.new(name, operation_count, Time::Span.new(nanoseconds: (total_time * 1_000_000).to_i), average_time, min_time, max_time, ops_per_sec)
  end

  private def benchmark_query_operation(name : String, operation_count : Int32, &block) : BenchmarkResult
    times = [] of Float64

    # Warmup
    5.times { block.call }

    # Benchmark
    operation_count.times do
      time = Benchmark.realtime do
        block.call
      end
      times << time.total_milliseconds
    end

    total_time = times.sum
    average_time = total_time / operation_count
    min_time = times.min
    max_time = times.max
    ops_per_sec = operation_count.to_f / (total_time / 1000.0)

    BenchmarkResult.new(name, operation_count, Time::Span.new(nanoseconds: (total_time * 1_000_000).to_i), average_time, min_time, max_time, ops_per_sec)
  end

  private def benchmark_association_operation(name : String, operation_count : Int32, &block) : BenchmarkResult
    times = [] of Float64

    # Warmup
    3.times { block.call }

    # Benchmark
    operation_count.times do
      time = Benchmark.realtime do
        block.call
      end
      times << time.total_milliseconds
    end

    total_time = times.sum
    average_time = total_time / operation_count
    min_time = times.min
    max_time = times.max
    ops_per_sec = operation_count.to_f / (total_time / 1000.0)

    BenchmarkResult.new(name, operation_count, Time::Span.new(nanoseconds: (total_time * 1_000_000).to_i), average_time, min_time, max_time, ops_per_sec)
  end

  private def benchmark_transaction_operation(name : String, operation_count : Int32, &block) : BenchmarkResult
    times = [] of Float64

    # Warmup
    2.times { block.call }

    # Benchmark
    operation_count.times do
      time = Benchmark.realtime do
        block.call
      end
      times << time.total_milliseconds
    end

    total_time = times.sum
    average_time = total_time / operation_count
    min_time = times.min
    max_time = times.max
    ops_per_sec = operation_count.to_f / (total_time / 1000.0)

    BenchmarkResult.new(name, operation_count, Time::Span.new(nanoseconds: (total_time * 1_000_000).to_i), average_time, min_time, max_time, ops_per_sec)
  end

  private def benchmark_memory_operation(name : String, operation_count : Int32, &block) : BenchmarkResult
    times = [] of Float64
    memory_usage_before = get_memory_usage_mb

    # Warmup
    1.times { block.call }

    # Benchmark
    operation_count.times do
      time = Benchmark.realtime do
        block.call
      end
      times << time.total_milliseconds
    end

    memory_usage_after = get_memory_usage_mb
    memory_increase = memory_usage_after - memory_usage_before

    total_time = times.sum
    average_time = total_time / operation_count
    min_time = times.min
    max_time = times.max
    ops_per_sec = operation_count.to_f / (total_time / 1000.0)

    BenchmarkResult.new(name, operation_count, Time::Span.new(nanoseconds: (total_time * 1_000_000).to_i), average_time, min_time, max_time, ops_per_sec, memory_increase)
  end

  private def create_benchmark_user
    user = PerformanceUser.new(
      name: "Benchmark User #{Random.rand(100000)}",
      email: "user#{Random.rand(100000)}@benchmark.com",
      age: Random.rand(18..80),
      active: true,
      created_at: Time.utc,
      updated_at: Time.utc
    )
    user_changeset = PerformanceUser.changeset(user)
    PerformanceRepo.insert(user_changeset)
  end

  private def read_benchmark_user(user_id : Int32)
    PerformanceRepo.get(PerformanceUser, user_id)
  end

  private def update_benchmark_user(user_id : Int32)
    if user = PerformanceRepo.get(PerformanceUser, user_id)
      user.updated_at = Time.utc
      user_changeset = PerformanceUser.changeset(user)
      PerformanceRepo.update(user_changeset)
    end
  end

  private def delete_benchmark_user(user_id : Int32)
    if user = PerformanceRepo.get(PerformanceUser, user_id)
      PerformanceRepo.delete(user)
    end
  end

  private def create_benchmark_user_in_tx(tx)
    user = PerformanceUser.new(
      name: "TX User #{Random.rand(100000)}",
      email: "txuser#{Random.rand(100000)}@benchmark.com",
      age: Random.rand(18..80),
      active: true,
      created_at: Time.utc,
      updated_at: Time.utc
    )
    user_changeset = PerformanceUser.changeset(user)
    PerformanceRepo.insert(user_changeset, tx)
  end

  private def create_benchmark_post_in_tx(user_id : Int32, tx)
    post = PerformancePost.new(
      title: "TX Post #{Random.rand(100000)}",
      content: "Content for transaction test post",
      user_id: user_id,
      published: true,
      created_at: Time.utc,
      updated_at: Time.utc
    )
    post_changeset = PerformancePost.changeset(post)
    PerformanceRepo.insert(post_changeset, tx)
  end

  private def create_benchmark_comment_in_tx(post_id : Int32, tx)
    comment = PerformanceComment.new(
      content: "TX Comment #{Random.rand(100000)}",
      post_id: post_id,
      author_name: "TX Commenter",
      created_at: Time.utc
    )
    comment_changeset = PerformanceComment.changeset(comment)
    PerformanceRepo.insert(comment_changeset, tx)
  end

  private def get_memory_usage_mb : Float64
    # Simple memory usage estimation
    # In a real implementation, you might use system-specific calls
    if File.exists?("/proc/#{Process.pid}/status")
      status = File.read("/proc/#{Process.pid}/status")
      if match = status.match(/VmRSS:\s+(\d+)\s+kB/)
        return match[1].to_f / 1024
      end
    end
    0.0
  end

  private def setup_performance_database
    begin
      # Create performance testing tables
      PerformanceRepo.exec("CREATE TABLE IF NOT EXISTS performance_users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        age INTEGER NOT NULL,
        active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )")

      PerformanceRepo.exec("CREATE TABLE IF NOT EXISTS performance_posts (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        published BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES performance_users(id)
      )")

      PerformanceRepo.exec("CREATE TABLE IF NOT EXISTS performance_comments (
        id INTEGER PRIMARY KEY,
        content TEXT NOT NULL,
        post_id INTEGER NOT NULL,
        author_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (post_id) REFERENCES performance_posts(id)
      )")

      # Create indexes for better performance
      PerformanceRepo.exec("CREATE INDEX IF NOT EXISTS idx_performance_users_email ON performance_users(email)")
      PerformanceRepo.exec("CREATE INDEX IF NOT EXISTS idx_performance_users_active ON performance_users(active)")
      PerformanceRepo.exec("CREATE INDEX IF NOT EXISTS idx_performance_posts_user_id ON performance_posts(user_id)")
      PerformanceRepo.exec("CREATE INDEX IF NOT EXISTS idx_performance_posts_published ON performance_posts(published)")
      PerformanceRepo.exec("CREATE INDEX IF NOT EXISTS idx_performance_comments_post_id ON performance_comments(post_id)")

    rescue ex
      puts "Error setting up performance database: #{ex.message}"
    end
  end

  private def seed_performance_data
    begin
      # Create seed data for benchmarks
      100.times do |i|
        user = PerformanceUser.new(
          name: "Performance User #{i}",
          email: "perfuser#{i}@benchmark.com",
          age: Random.rand(18..80),
          active: true,
          created_at: Time.utc,
          updated_at: Time.utc
        )
        user_changeset = PerformanceUser.changeset(user)
        created_user = PerformanceRepo.insert(user_changeset)

        if created_user
          # Create posts for each user
          post_count = Random.rand(1..5)
          post_count.times do |j|
            post = PerformancePost.new(
              title: "Performance Post #{i}-#{j}",
              content: "Content for performance testing post #{i}-#{j}",
              user_id: created_user.id.not_nil!,
              published: Random.rand(2) == 1,
              created_at: Time.utc,
              updated_at: Time.utc
            )
            post_changeset = PerformancePost.changeset(post)
            created_post = PerformanceRepo.insert(post_changeset)

            if created_post && created_post.published
              # Create comments for published posts
              comment_count = Random.rand(1..3)
              comment_count.times do |k|
                comment = PerformanceComment.new(
                  content: "Performance comment #{i}-#{j}-#{k}",
                  post_id: created_post.id.not_nil!,
                  author_name: "Commenter #{k}",
                  created_at: Time.utc
                )
                comment_changeset = PerformanceComment.changeset(comment)
                PerformanceRepo.insert(comment_changeset)
              end
            end
          end
        end
      end

    rescue ex
      puts "Error seeding performance data: #{ex.message}"
    end
  end

  private def cleanup_performance_database
    begin
      PerformanceRepo.exec("DROP TABLE IF EXISTS performance_comments")
      PerformanceRepo.exec("DROP TABLE IF EXISTS performance_posts")
      PerformanceRepo.exec("DROP TABLE IF EXISTS performance_users")
    rescue ex
      puts "Error cleaning up performance database: #{ex.message}"
    end
  end

  private def save_benchmark_results
    return if @@benchmark_results.empty?

    timestamp = Time.utc.to_s("%Y%m%d_%H%M%S")
    results_file = "spec/performance/results_#{timestamp}.json"

    results_data = @@benchmark_results.map do |name, result|
      {
        "name" => name,
        "operation_count" => result.operation_count,
        "total_time_ms" => result.total_time.total_milliseconds,
        "average_time_ms" => result.average_time,
        "min_time_ms" => result.min_time,
        "max_time_ms" => result.max_time,
        "operations_per_second" => result.operations_per_second,
        "memory_usage_mb" => result.memory_usage_mb,
        "timestamp" => result.timestamp.to_s
      }
    end

    File.write(results_file, results_data.to_json)
    puts "\n📄 Benchmark results saved to: #{results_file}"
  end
end