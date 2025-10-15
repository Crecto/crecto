#!/usr/bin/env crystal
require "./spec/load/load_test_helper"
require "benchmark"

# Performance benchmark script to reproduce load test issues

class PerformanceBenchmark
  def initialize
    @config = Crecto::LoadTesting::Config.new
    setup_test_database
  end

  def run_all_benchmarks
    puts "=" * 60
    puts "CRECTO PERFORMANCE BENCHMARK SUITE"
    puts "=" * 60

    # Test different scenarios
    benchmark_basic_crud
    benchmark_high_volume_inserts
    benchmark_concurrent_operations
    benchmark_connection_pool_stress

    cleanup_test_database
  end

  private def benchmark_basic_crud
    puts "\n1. Basic CRUD Operations Benchmark"
    puts "-" * 40

    # Clear existing data
    Crecto::LoadTesting::TestRepo.raw_exec("DELETE FROM load_test_models")

    stats = {
      insert: [] of Float64,
      update: [] of Float64,
      query: [] of Float64,
      delete: [] of Float64
    }

    100.times do |i|
      # Insert
      time = Benchmark.realtime do
        model = Crecto::LoadTesting::LoadTestModel.new
        model.name = "Test Item #{i}"
        model.value = i
        model.created_at = Time.local
        Crecto::LoadTesting::TestRepo.insert(model)
      end
      stats[:insert] << time.total_seconds

      # Query
      time = Benchmark.realtime do
        Crecto::LoadTesting::TestRepo.all(
          Crecto::LoadTesting::LoadTestModel,
          Crecto::Repo::Query.where("value > ?", i - 10).limit(10)
        )
      end
      stats[:query] << time.total_seconds

      # Update
      time = Benchmark.realtime do
        results = Crecto::LoadTesting::TestRepo.all(
          Crecto::LoadTesting::LoadTestModel,
          Crecto::Repo::Query.where("name = ?", "Test Item #{i}").limit(1)
        )
        if model = results.first?
          model.name = "Updated Test Item #{i}"
          Crecto::LoadTesting::TestRepo.update(model)
        end
      end
      stats[:update] << time.total_seconds

      # Delete
      if i > 50
        time = Benchmark.realtime do
          results = Crecto::LoadTesting::TestRepo.all(
            Crecto::LoadTesting::LoadTestModel,
            Crecto::Repo::Query.where("name = ?", "Updated Test Item #{i - 50}").limit(1)
          )
          if model = results.first?
            Crecto::LoadTesting::TestRepo.delete(model)
          end
        end
        stats[:delete] << time.total_seconds
      end
    end

    print_stats("Insert", stats[:insert])
    print_stats("Query", stats[:query])
    print_stats("Update", stats[:update])
    print_stats("Delete", stats[:delete])
  end

  private def benchmark_high_volume_inserts
    puts "\n2. High-Volume Inserts Benchmark"
    puts "-" * 40

    # Clear existing data
    Crecto::LoadTesting::TestRepo.raw_exec("DELETE FROM load_test_models")

    batch_sizes = [1, 10, 50, 100, 500, 1000]

    batch_sizes.each do |batch_size|
      puts "\nTesting batch size: #{batch_size}"

      times = [] of Float64
      errors = 0

      5.times do  # Run 5 iterations for each batch size
        begin
          time = Benchmark.realtime do
            Crecto::LoadTesting::TestRepo.transaction! do |tx|
              batch_size.times do |i|
                model = Crecto::LoadTesting::LoadTestModel.new
                model.name = "Batch Test #{batch_size}-#{i}"
                model.value = i
                model.created_at = Time.local
                tx.insert!(model)
              end
            end
          end
          times << time.total_seconds

          # Verify records were inserted
          count = Crecto::LoadTesting::TestRepo.aggregate(
            Crecto::LoadTesting::LoadTestModel,
            :count,
            :id
          )
          puts "  Records in database: #{count}"

          # Clean up for next test
          Crecto::LoadTesting::TestRepo.raw_exec("DELETE FROM load_test_models")

        rescue ex
          errors += 1
          puts "  ERROR: #{ex.message}"
        end
      end

      if times.any?
        avg_time = times.sum / times.size
        ops_per_sec = batch_size / avg_time
        puts "  Average time: #{avg_time.round(4)}s"
        puts "  Operations/sec: #{ops_per_sec.round(2)}"
      end

      puts "  Errors: #{errors}" if errors > 0
    end
  end

  private def benchmark_concurrent_operations
    puts "\n3. Concurrent Operations Benchmark"
    puts "-" * 40

    # Clear existing data
    Crecto::LoadTesting::TestRepo.raw_exec("DELETE FROM load_test_models")

    channel = Channel(Nil).new
    errors = [] of String
    errors_lock = Mutex.new

    # Spawn concurrent workers
    workers = 20
    operations_per_worker = 50

    puts "Spawning #{workers} workers with #{operations_per_worker} operations each"

    start_time = Time.local

    workers.times do |worker_id|
      spawn do
        begin
          operations_per_worker.times do |i|
            model = Crecto::LoadTesting::LoadTestModel.new
            model.name = "Concurrent Test #{worker_id}-#{i}"
            model.value = worker_id * 1000 + i
            model.created_at = Time.local

            result = Crecto::LoadTesting::TestRepo.insert(model)

            if result.is_a?(Crecto::Changeset::Changeset) && !result.valid?
              errors_lock.synchronize do
                errors << "Worker #{worker_id}: Insert validation failed: #{result.errors}"
              end
            end
          end
        rescue ex
          errors_lock.synchronize do
            errors << "Worker #{worker_id}: Exception: #{ex.message}"
          end
        end
        channel.send(nil)
      end
    end

    # Wait for all workers to complete
    workers.times { channel.receive }

    end_time = Time.local
    total_time = end_time - start_time

    # Verify final state
    count = Crecto::LoadTesting::TestRepo.aggregate(
      Crecto::LoadTesting::LoadTestModel,
      :count,
      :id
    )

    puts "Total time: #{total_time.total_seconds.round(3)}s"
    puts "Expected records: #{workers * operations_per_worker}"
    puts "Actual records: #{count}"
    puts "Success rate: #{(count.to_f / (workers * operations_per_worker) * 100).round(2)}%"
    puts "Operations/sec: #{(workers * operations_per_worker) / total_time.total_seconds.round(2)}"
    puts "Errors: #{errors.size}"

    if errors.any?
      puts "First few errors:"
      errors.first(5).each { |e| puts "  - #{e}" }
    end
  end

  private def benchmark_connection_pool_stress
    puts "\n4. Connection Pool Stress Test"
    puts "-" * 40

    # Test with different pool configurations
    pool_configs = [
      {initial_pool_size: 1, max_pool_size: 5},
      {initial_pool_size: 5, max_pool_size: 10},
      {initial_pool_size: 10, max_pool_size: 20},
      {initial_pool_size: 20, max_pool_size: 50}
    ]

    pool_configs.each do |config|
      puts "\nTesting pool config: initial=#{config[:initial_pool_size]}, max=#{config[:max_pool_size]}"

      # Create a new repo with this config
      test_repo = create_test_repo(config)

      # Clear data
      test_repo.raw_exec("DELETE FROM load_test_models")

      channel = Channel(Nil).new
      errors = [] of String
      errors_lock = Mutex.new
      times = [] of Float64

      start_time = Time.local

      50.times do |i|
        spawn do
          begin
            time = Benchmark.realtime do
              10.times do |j|
                model = Crecto::LoadTesting::LoadTestModel.new
                model.name = "Pool Test #{i}-#{j}"
                model.value = i * 10 + j
                model.created_at = Time.local
                test_repo.insert(model)
              end
            end
            times << time.total_seconds
          rescue ex
            errors_lock.synchronize do
              errors << "Thread #{i}: #{ex.message}"
            end
          end
          channel.send(nil)
        end
      end

      50.times { channel.receive }

      end_time = Time.local

      if times.any?
        avg_time = times.sum / times.size
        puts "  Average thread time: #{avg_time.round(4)}s"
        puts "  Total operations: 500"
        puts "  Total time: #{(end_time - start_time).total_seconds.round(3)}s"
        puts "  Ops/sec: #{500 / (end_time - start_time).total_seconds.round(2)}"
        puts "  Errors: #{errors.size}"
      end

      # Close the database connection
      test_repo.crecto_db.try(&.close)
    end
  end

  end

# Define test repo modules at module level
module TestRepoPool1
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./spec/load/pool_test_1.db"
    conf.initial_pool_size = 1
    conf.max_pool_size = 5
    conf.max_idle_pool_size = 2
    conf.checkout_timeout = 5.0
  end
end

module TestRepoPool2
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./spec/load/pool_test_2.db"
    conf.initial_pool_size = 5
    conf.max_pool_size = 10
    conf.max_idle_pool_size = 5
    conf.checkout_timeout = 5.0
  end
end

module TestRepoPool3
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./spec/load/pool_test_3.db"
    conf.initial_pool_size = 10
    conf.max_pool_size = 20
    conf.max_idle_pool_size = 10
    conf.checkout_timeout = 5.0
  end
end

module TestRepoPool4
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = "./spec/load/pool_test_4.db"
    conf.initial_pool_size = 20
    conf.max_pool_size = 50
    conf.max_idle_pool_size = 25
    conf.checkout_timeout = 5.0
  end
end

# Extend the PerformanceBenchmark class with the fixed method
class PerformanceBenchmark
  private def create_test_repo(pool_config)
    case pool_config[:max_pool_size]
    when 5
      TestRepoPool1
    when 10
      TestRepoPool2
    when 20
      TestRepoPool3
    when 50
      TestRepoPool4
    else
      TestRepoPool1
    end
  end

  private def print_stats(operation, times)
    return if times.empty?

    avg = times.sum / times.size
    min = times.min
    max = times.max
    p95 = times.sort[(times.size * 0.95).to_i]

    puts "  #{operation}:"
    puts "    Average: #{(avg * 1000).round(2)}ms"
    puts "    Min: #{(min * 1000).round(2)}ms"
    puts "    Max: #{(max * 1000).round(2)}ms"
    puts "    95th percentile: #{(p95 * 1000).round(2)}ms"
    puts "    Ops/sec: #{(1.0 / avg).round(2)}"
  end
end

# Run the benchmark
benchmark = PerformanceBenchmark.new
benchmark.run_all_benchmarks