require "../../spec/spec_helper"
require "../../src/crecto"

# Setup and cleanup functions for load testing
def setup_test_database
  # Create test database and table
  begin
    Crecto::LoadTesting::TestRepo.raw_exec("DROP TABLE IF EXISTS load_test_models")
    Crecto::LoadTesting::TestRepo.raw_exec(%{
      CREATE TABLE load_test_models (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL,
        value INTEGER NOT NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL
      )
    })
    Crecto::LoadTesting::TestRepo.raw_exec("CREATE INDEX idx_load_test_models_value ON load_test_models(value)")
    Crecto::LoadTesting::TestRepo.raw_exec("CREATE INDEX idx_load_test_models_created_at ON load_test_models(created_at)")
  rescue ex
    puts "Database setup failed: #{ex.message}"
  end
end

def cleanup_test_database
  begin
    Crecto::LoadTesting::TestRepo.raw_exec("DROP TABLE IF EXISTS load_test_models")
  rescue ex
    puts "Database cleanup failed: #{ex.message}"
  end

  # Remove database file
  db_file = "./spec/load/load_test.db"
  File.delete(db_file) if File.exists?(db_file)
end

# Association test setup and cleanup functions
def setup_association_test_database
  begin
    AssociationTestRepo.raw_exec("DROP TABLE IF EXISTS association_comments")
    AssociationTestRepo.raw_exec("DROP TABLE IF EXISTS association_posts")
    AssociationTestRepo.raw_exec("DROP TABLE IF EXISTS association_users")

    AssociationTestRepo.raw_exec(%{
      CREATE TABLE association_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL
      )
    })

    AssociationTestRepo.raw_exec(%{
      CREATE TABLE association_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        user_id INTEGER NOT NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        FOREIGN KEY (user_id) REFERENCES association_users(id)
      )
    })

    AssociationTestRepo.raw_exec(%{
      CREATE TABLE association_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        post_id INTEGER NOT NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        FOREIGN KEY (user_id) REFERENCES association_users(id),
        FOREIGN KEY (post_id) REFERENCES association_posts(id)
      )
    })

    # Create indexes
    AssociationTestRepo.raw_exec("CREATE INDEX idx_association_posts_user_id ON association_posts(user_id)")
    AssociationTestRepo.raw_exec("CREATE INDEX idx_association_comments_user_id ON association_comments(user_id)")
    AssociationTestRepo.raw_exec("CREATE INDEX idx_association_comments_post_id ON association_comments(post_id)")
    AssociationTestRepo.raw_exec("CREATE INDEX idx_association_users_created_at ON association_users(created_at)")
    AssociationTestRepo.raw_exec("CREATE INDEX idx_association_posts_created_at ON association_posts(created_at)")
  rescue ex
    puts "Association database setup failed: #{ex.message}"
  end
end

def cleanup_association_test_database
  begin
    AssociationTestRepo.raw_exec("DROP TABLE IF EXISTS association_comments")
    AssociationTestRepo.raw_exec("DROP TABLE IF EXISTS association_posts")
    AssociationTestRepo.raw_exec("DROP TABLE IF EXISTS association_users")
  rescue ex
    puts "Association database cleanup failed: #{ex.message}"
  end

  # Remove database file
  db_file = "./spec/load/association_test.db"
  File.delete(db_file) if File.exists?(db_file)
end

# Load testing framework for Crecto
# Provides utilities for stress testing CRUD operations under high load

module Crecto
  module LoadTesting
    # Load test configuration
    class Config
      property operation_counts : Hash(String, Int32) = {
        "insert" => 1000,
        "update" => 1000,
        "delete" => 500,
        "query" => 2000,
        "association" => 500
      }

      property concurrent_workers : Int32 = 10
      property test_duration_seconds : Int32 = 60
      property memory_limit_mb : Int32 = 512
      property warmup_seconds : Int32 = 5
      property cooldown_seconds : Int32 = 5

      # Database-specific settings
      property batch_size : Int32 = 100
      property connection_pool_size : Int32 = 20

      def initialize(@operation_counts = operation_counts, @concurrent_workers = concurrent_workers)
      end
    end

    # Load test statistics
    class Stats
      property total_operations : Int64 = 0
      property successful_operations : Int64 = 0
      property failed_operations : Int64 = 0
      property total_time : Time::Span = Time::Span.zero
      property memory_usage_mb : Float64 = 0.0
      property errors : Array(String) = [] of String
      property operations_per_second : Float64 = 0.0

      def start_timing
        @start_time = Time.local
      end

      def end_timing
        if start_time = @start_time
          @total_time = Time.local - start_time
          @operations_per_second = @successful_operations.to_f64 / @total_time.total_seconds
        end
      end

      def success_rate : Float64
        return 0.0 if total_operations == 0
        (successful_operations.to_f64 / total_operations.to_f64 * 100).round(2)
      end

      def to_h : Hash(String, Float64 | Int64 | String)
        {
          "total_operations" => total_operations,
          "successful_operations" => successful_operations,
          "failed_operations" => failed_operations,
          "success_rate_percent" => success_rate,
          "operations_per_second" => operations_per_second.round(2),
          "total_time_seconds" => total_time.total_seconds.round(3),
          "memory_usage_mb" => memory_usage_mb.round(2),
          "error_count" => errors.size
        }
      end
    end

    # Generic load test runner
    class Runner
      @repo : Repo

      def initialize(@config : Config, @repo)
        @stats = Stats.new
      end

      def initialize(@config : Config)
        initialize(@config, TestRepo)
      end

      def run_load_test(test_name : String) : Stats
        puts "\n=== Starting Load Test: #{test_name} ==="
        puts "Configuration: #{@config.concurrent_workers} workers, #{@config.operation_counts.values.sum} total operations"

        # Warmup phase
        warmup_phase

        # Main test phase
        @stats.start_timing
        main_test_phase
        @stats.end_timing

        # Cooldown phase
        cooldown_phase

        # Calculate memory usage
        @stats.memory_usage_mb = calculate_memory_usage

        # Print results
        print_results(test_name)

        @stats
      end

      private def warmup_phase
        puts "Warming up for #{@config.warmup_seconds} seconds..."
        sleep @config.warmup_seconds.seconds
      end

      private def cooldown_phase
        puts "Cooling down for #{@config.cooldown_seconds} seconds..."
        sleep @config.cooldown_seconds.seconds
      end

      private def main_test_phase
        # Create channel for coordinating workers
        result_channel = Channel(Stats).new(@config.concurrent_workers)

        # Spawn worker fibers
        @config.concurrent_workers.times do |worker_id|
          spawn do
            worker_stats = run_worker(worker_id)
            result_channel.send(worker_stats)
          end
        end

        # Collect results from all workers
        @config.concurrent_workers.times do
          worker_result = result_channel.receive
          aggregate_worker_stats(worker_result)
        end
      end

      private def run_worker(worker_id : Int32) : Stats
        worker_stats = Stats.new

        @config.operation_counts.each do |operation, count|
          operations_per_worker = (count / @config.concurrent_workers).ceil.to_i32

          operations_per_worker.times do |i|
            begin
              case operation
              when "insert"
                test_insert_operation(worker_stats)
              when "update"
                test_update_operation(worker_stats)
              when "delete"
                test_delete_operation(worker_stats)
              when "query"
                test_query_operation(worker_stats)
              when "association"
                test_association_operation(worker_stats)
              end

              worker_stats.successful_operations += 1
            rescue ex : Exception
              worker_stats.failed_operations += 1
              worker_stats.errors << "#{operation} failed: #{ex.message}"
            end

            worker_stats.total_operations += 1
          end
        end

        worker_stats
      end

      private def aggregate_worker_stats(worker_stats : Stats)
        @stats.total_operations += worker_stats.total_operations
        @stats.successful_operations += worker_stats.successful_operations
        @stats.failed_operations += worker_stats.failed_operations
        @stats.errors.concat(worker_stats.errors)
      end

      # Test operations to be implemented by specific test classes
      protected def test_insert_operation(stats : Stats)
        raise NotImplementedError.new("Subclasses must implement test_insert_operation")
      end

      protected def test_update_operation(stats : Stats)
        raise NotImplementedError.new("Subclasses must implement test_update_operation")
      end

      protected def test_delete_operation(stats : Stats)
        raise NotImplementedError.new("Subclasses must implement test_delete_operation")
      end

      protected def test_query_operation(stats : Stats)
        raise NotImplementedError.new("Subclasses must implement test_query_operation")
      end

      protected def test_association_operation(stats : Stats)
        raise NotImplementedError.new("Subclasses must implement test_association_operation")
      end

      private def calculate_memory_usage : Float64
        GC.stats.heap_size.to_f64 / (1024 * 1024)
      end

      private def print_results(test_name : String)
        puts "\n=== Load Test Results: #{test_name} ==="
        puts "Total Operations: #{@stats.total_operations}"
        puts "Successful: #{@stats.successful_operations}"
        puts "Failed: #{@stats.failed_operations}"
        puts "Success Rate: #{@stats.success_rate}%"
        puts "Operations/Second: #{@stats.operations_per_second.round(2)}"
        puts "Total Time: #{@stats.total_time.total_seconds.round(3)}s"
        puts "Memory Usage: #{@stats.memory_usage_mb.round(2)} MB"

        if @stats.errors.size > 0
          puts "\nErrors (first 5):"
          @stats.errors.first(5).each { |error| puts "  - #{error}" }
        end

        puts "=" * 50
      end
    end

    # Test model for load testing
    class LoadTestModel < Crecto::Model
      schema "load_test_models" do
        field :id, Int64, primary_key: true
        field :name, String
        field :value, Int32
        field :created_at, Time
      end
    end

    # Test repository
    module TestRepo
      extend Crecto::Repo

      config do |conf|
        conf.adapter = Crecto::Adapters::SQLite3
        conf.database = "./spec/load/load_test.db"
      end
    end
  end
end