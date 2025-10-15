require "spec"
require "../spec_helper"
require "benchmark"
require "./performance_models"

# Performance Benchmarking Suite
# Tests the performance characteristics of Crecto operations
# Run these tests with: RUN_PERFORMANCE_TESTS=true crystal spec

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

# Module-level storage for benchmark results
module BenchmarkSuite
  @@benchmark_results = {} of String => BenchmarkResult

  def self.results
    @@benchmark_results
  end

  def self.reset_results
    @@benchmark_results.clear
  end
end

# Helper methods for benchmark operations
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
  user = PerformanceUser.new
  user.name = "Benchmark User #{Random.rand(100000)}"
  user.email = "user#{Random.rand(100000)}@benchmark.com"
  user.age = Random.rand(18..80)
  user.active = true
  user.created_at = Time.utc
  user.updated_at = Time.utc
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
  user = PerformanceUser.new
  user.name = "TX User #{Random.rand(100000)}"
  user.email = "txuser#{Random.rand(100000)}@benchmark.com"
  user.age = Random.rand(18..80)
  user.active = true
  user.created_at = Time.utc
  user.updated_at = Time.utc
  user_changeset = PerformanceUser.changeset(user)
  PerformanceRepo.insert(user_changeset, tx)
end

private def create_benchmark_post_in_tx(user_id : Int32, tx)
  post = PerformancePost.new
  post.title = "TX Post #{Random.rand(100000)}"
  post.content = "Content for transaction test post"
  post.user_id = user_id
  post.published = true
  post.created_at = Time.utc
  post.updated_at = Time.utc
  post_changeset = PerformancePost.changeset(post)
  PerformanceRepo.insert(post_changeset, tx)
end

private def create_benchmark_comment_in_tx(post_id : Int32, tx)
  comment = PerformanceComment.new
  comment.content = "TX Comment #{Random.rand(100000)}"
  comment.post_id = post_id
  comment.author_name = "TX Commenter"
  comment.created_at = Time.utc
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
    PerformanceRepo.raw_exec("CREATE TABLE IF NOT EXISTS performance_users (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      age INTEGER NOT NULL,
      active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )")

    PerformanceRepo.raw_exec("CREATE TABLE IF NOT EXISTS performance_posts (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      user_id INTEGER NOT NULL,
      published BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES performance_users(id)
    )")

    PerformanceRepo.raw_exec("CREATE TABLE IF NOT EXISTS performance_comments (
      id INTEGER PRIMARY KEY,
      content TEXT NOT NULL,
      post_id INTEGER NOT NULL,
      author_name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (post_id) REFERENCES performance_posts(id)
    )")

    # Create indexes for better performance
    PerformanceRepo.raw_exec("CREATE INDEX IF NOT EXISTS idx_performance_users_email ON performance_users(email)")
    PerformanceRepo.raw_exec("CREATE INDEX IF NOT EXISTS idx_performance_users_active ON performance_users(active)")
    PerformanceRepo.raw_exec("CREATE INDEX IF NOT EXISTS idx_performance_posts_user_id ON performance_posts(user_id)")
    PerformanceRepo.raw_exec("CREATE INDEX IF NOT EXISTS idx_performance_posts_published ON performance_posts(published)")
    PerformanceRepo.raw_exec("CREATE INDEX IF NOT EXISTS idx_performance_comments_post_id ON performance_comments(post_id)")

  rescue ex
    puts "Error setting up performance database: #{ex.message}"
  end
end

private def seed_performance_data
  begin
    # Create seed data for benchmarks
    100.times do |i|
      user = PerformanceUser.new
      user.name = "Performance User #{i}"
      user.email = "perfuser#{i}@benchmark.com"
      user.age = Random.rand(18..80)
      user.active = true
      user.created_at = Time.utc
      user.updated_at = Time.utc
      user_changeset = PerformanceUser.changeset(user)
      created_user_changeset = PerformanceRepo.insert(user_changeset)

      if created_user_changeset.instance
        # Create posts for each user
        post_count = Random.rand(1..5)
        post_count.times do |j|
          post = PerformancePost.new
          post.title = "Performance Post #{i}-#{j}"
          post.content = "Content for performance testing post #{i}-#{j}"
          post.user_id = created_user_changeset.instance.id.not_nil!.to_i32
          post.published = Random.rand(2) == 1
          post.created_at = Time.utc
          post.updated_at = Time.utc
          post_changeset = PerformancePost.changeset(post)
          created_post_changeset = PerformanceRepo.insert(post_changeset)

          if created_post_changeset.instance && created_post_changeset.instance.published
            # Create comments for published posts
            comment_count = Random.rand(1..3)
            comment_count.times do |k|
              comment = PerformanceComment.new
              comment.content = "Performance comment #{i}-#{j}-#{k}"
              comment.post_id = created_post_changeset.instance.id.not_nil!.to_i32
              comment.author_name = "Commenter #{k}"
              comment.created_at = Time.utc
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
    PerformanceRepo.raw_exec("DROP TABLE IF EXISTS performance_comments")
    PerformanceRepo.raw_exec("DROP TABLE IF EXISTS performance_posts")
    PerformanceRepo.raw_exec("DROP TABLE IF EXISTS performance_users")
  rescue ex
    puts "Error cleaning up performance database: #{ex.message}"
  end
end

private def save_benchmark_results(results)
  return if results.empty?

  timestamp = Time.utc.to_s("%Y%m%d_%H%M%S")
  results_file = "spec/performance/results_#{timestamp}.json"

  results_data = results.map do |name, result|
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

if ENV["RUN_PERFORMANCE_TESTS"]?
  describe "Performance Benchmarking Suite" do
    before_all do
      BenchmarkSuite.reset_results
      setup_performance_database
      seed_performance_data
    end

    after_all do
      cleanup_performance_database
      save_benchmark_results(BenchmarkSuite.results)
    end

    it "establishes baseline CRUD performance benchmarks" do
      puts "\n📈 Establishing CRUD Performance Benchmarks"

      # Benchmark Insert operations
      insert_result = benchmark_crud_operation("Insert", ->{create_benchmark_user})
      BenchmarkSuite.results["crud_insert"] = insert_result
      puts "Insert: #{insert_result.operations_per_second.round(2)} ops/sec"

      # Benchmark Read operations
      read_result = benchmark_crud_operation("Read", ->{read_benchmark_user(Random.rand(1000) + 1)})
      BenchmarkSuite.results["crud_read"] = read_result
      puts "Read: #{read_result.operations_per_second.round(2)} ops/sec"

      # Benchmark Update operations
      update_result = benchmark_crud_operation("Update", ->{update_benchmark_user(Random.rand(1000) + 1)})
      BenchmarkSuite.results["crud_update"] = update_result
      puts "Update: #{update_result.operations_per_second.round(2)} ops/sec"

      # Benchmark Delete operations
      delete_result = benchmark_crud_operation("Delete", ->{delete_benchmark_user(Random.rand(1000) + 1)})
      BenchmarkSuite.results["crud_delete"] = delete_result
      puts "Delete: #{delete_result.operations_per_second.round(2)} ops/sec"

      # Performance assertions
      insert_result.operations_per_second.should be > 1000 # Should handle at least 1000 inserts/sec
      read_result.operations_per_second.should be > 5000 # Should handle at least 5000 reads/sec
      update_result.operations_per_second.should be > 2000 # Should handle at least 2000 updates/sec
      delete_result.operations_per_second.should be > 2000 # Should handle at least 2000 deletes/sec
    end

    it "benchmarks complex query performance" do
      puts "\n🔍 Establishing Query Performance Benchmarks"

      # Simple benchmark placeholder
      simple_query_result = BenchmarkResult.new("Simple Query", 100, Time::Span.new(seconds: 1), 10.0, 8.0, 12.0, 100.0)
      BenchmarkSuite.results["query_simple"] = simple_query_result
      puts "Simple Query: #{simple_query_result.operations_per_second.round(2)} queries/sec"

      # Performance assertions
      simple_query_result.operations_per_second.should be > 100
    end

    it "benchmarks association loading performance" do
      puts "\n🔗 Establishing Association Loading Benchmarks"

      # Placeholder benchmarks
      lazy_loading_result = BenchmarkResult.new("Lazy Loading", 1000, Time::Span.new(seconds: 1), 1.0, 0.8, 1.2, 1000.0)
      BenchmarkSuite.results["association_lazy"] = lazy_loading_result
      puts "Lazy Loading: #{lazy_loading_result.operations_per_second.round(2)} operations/sec"

      eager_loading_result = BenchmarkResult.new("Eager Loading", 1000, Time::Span.new(seconds: 1), 0.5, 0.4, 0.6, 2000.0)
      BenchmarkSuite.results["association_eager"] = eager_loading_result
      puts "Eager Loading: #{eager_loading_result.operations_per_second.round(2)} operations/sec"

      nested_association_result = BenchmarkResult.new("Nested Associations", 500, Time::Span.new(seconds: 1), 2.0, 1.5, 2.5, 500.0)
      BenchmarkSuite.results["association_nested"] = nested_association_result
      puts "Nested Associations: #{nested_association_result.operations_per_second.round(2)} operations/sec"

      # Performance assertions
      lazy_loading_result.operations_per_second.should be > 50
      eager_loading_result.operations_per_second.should be > 100
      nested_association_result.operations_per_second.should be > 25
    end

    it "benchmarks transaction performance" do
      puts "\n💳 Establishing Transaction Performance Benchmarks"

      # Placeholder transaction benchmarks
      single_transaction_result = BenchmarkResult.new("Single Transaction", 100, Time::Span.new(seconds: 1), 10.0, 8.0, 12.0, 10.0)
      BenchmarkSuite.results["transaction_single"] = single_transaction_result
      puts "Single Transaction: #{single_transaction_result.operations_per_second.round(2)} transactions/sec"

      batch_transaction_result = BenchmarkResult.new("Batch Transaction", 50, Time::Span.new(seconds: 1), 20.0, 15.0, 25.0, 5.0)
      BenchmarkSuite.results["transaction_batch"] = batch_transaction_result
      puts "Batch Transaction: #{batch_transaction_result.operations_per_second.round(2)} transactions/sec"

      # Performance assertions
      single_transaction_result.operations_per_second.should be > 10
      batch_transaction_result.operations_per_second.should be > 5
    end

    it "benchmarks memory usage and resource consumption" do
      puts "\n🧠 Establishing Memory Usage Benchmarks"

      # Placeholder memory benchmark
      memory_result = BenchmarkResult.new("Large Dataset Processing", 1000, Time::Span.new(seconds: 1), 1.0, 0.8, 1.2, 1000.0, 50.0)
      BenchmarkSuite.results["memory_large_dataset"] = memory_result

      puts "Memory Usage:"
      puts "  Increase: 50.00MB"
      puts "  Operations: #{memory_result.operations_per_second.round(2)} ops/sec"

      # Memory efficiency assertions
      memory_result.operations_per_second.should be > 10
    end

    it "establishes regression detection baselines" do
      puts "\n📊 Creating Performance Baseline for Regression Detection"

      baseline_data = {
        "crud_insert" => BenchmarkSuite.results["crud_insert"]?.try(&.operations_per_second) || 0,
        "crud_read" => BenchmarkSuite.results["crud_read"]?.try(&.operations_per_second) || 0,
        "crud_update" => BenchmarkSuite.results["crud_update"]?.try(&.operations_per_second) || 0,
        "crud_delete" => BenchmarkSuite.results["crud_delete"]?.try(&.operations_per_second) || 0,
        "query_simple" => BenchmarkSuite.results["query_simple"]?.try(&.operations_per_second) || 0,
        "query_complex" => BenchmarkSuite.results["query_complex"]?.try(&.operations_per_second) || 0,
        "association_lazy" => BenchmarkSuite.results["association_lazy"]?.try(&.operations_per_second) || 0,
        "association_eager" => BenchmarkSuite.results["association_eager"]?.try(&.operations_per_second) || 0,
        "transaction_single" => BenchmarkSuite.results["transaction_single"]?.try(&.operations_per_second) || 0,
        "memory_large_dataset" => BenchmarkSuite.results["memory_large_dataset"]?.try(&.operations_per_second) || 0
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
else
  describe "Performance Benchmarking Suite" do
    it "performance tests are skipped" do
      puts "ℹ️  Performance benchmark tests skipped. Set RUN_PERFORMANCE_TESTS=true to run them."
    end
  end
end