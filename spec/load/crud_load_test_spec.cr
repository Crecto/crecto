require "spec"
require "./load_test_helper"

# CRUD Operations Load Testing
# Tests the performance and stability of basic CRUD operations under sustained load

describe "CRUD Load Testing" do
  before_all do
    # Setup test database
    setup_test_database
  end

  after_all do
    # Cleanup test database
    cleanup_test_database
  end

  describe "Basic CRUD Load Test" do
    it "handles sustained CRUD operations under high load" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {
          "insert" => 500,
          "update" => 500,
          "delete" => 250,
          "query" => 1000
        },
        concurrent_workers: 5
      )

      runner = CRUDLoadTestRunner.new(config)
      stats = runner.run_load_test("Basic CRUD Operations")

      # Assert basic performance requirements
      stats.success_rate.should be > 95.0
      stats.operations_per_second.should be > 50.0
      stats.memory_usage_mb.should be < 256.0
      stats.failed_operations.should be < (stats.total_operations * 0.1).to_i
    end

    it "handles high-volume insert operations" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {"insert" => 2000},
        concurrent_workers: 10
      )

      runner = CRUDLoadTestRunner.new(config)
      stats = runner.run_load_test("High-Volume Inserts")

      stats.success_rate.should be > 98.0
      stats.operations_per_second.should be > 100.0
    end

    it "handles concurrent query operations" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {"query" => 5000},
        concurrent_workers: 15
      )

      runner = CRUDLoadTestRunner.new(config)
      stats = runner.run_load_test("Concurrent Queries")

      stats.success_rate.should be > 99.0
      stats.operations_per_second.should be > 200.0
    end
  end

  describe "Stress Testing" do
    it "handles extreme load without memory leaks" do
      config = Crecto::LoadTesting::Config.new(
        operation_counts: {
          "insert" => 1000,
          "update" => 1000,
          "query" => 2000,
          "delete" => 500
        },
        concurrent_workers: 8
      )
      config.test_duration_seconds = 15
      config.warmup_seconds = 2
      config.cooldown_seconds = 2

      runner = CRUDLoadTestRunner.new(config)
      stats = runner.run_load_test("Extreme Load Stress Test")

      # Even under extreme load, basic requirements should be met
      stats.success_rate.should be > 90.0
      stats.memory_usage_mb.should be < 512.0
    end
  end
end

# CRUD-specific load test runner
class CRUDLoadTestRunner < Crecto::LoadTesting::Runner
  def initialize(config = Crecto::LoadTesting::Config.new)
    super(config, Crecto::LoadTesting::TestRepo)
    @test_data_lock = Mutex.new
    @created_ids = [] of Int64
    @next_id = 1_i64
  end

  protected def test_insert_operation(stats : Crecto::LoadTesting::Stats)
    model = Crecto::LoadTesting::LoadTestModel.new
    model.name = "Load Test Item #{@next_id}"
    model.value = @next_id.to_i32
    model.created_at = Time.local

    result = Crecto::LoadTesting::TestRepo.insert(model)

    if result.is_a?(Crecto::Changeset::Changeset)
      if result.valid?
        # Track successful insert
        @test_data_lock.synchronize do
          if model_instance = result.instance
            @created_ids << model_instance.id.as(Int64)
          end
          @next_id += 1
        end
      else
        raise Exception.new("Insert validation failed: #{result.errors}")
      end
    else
      @test_data_lock.synchronize do
        @created_ids << result.id.as(Int64)
        @next_id += 1
      end
    end
  end

  protected def test_update_operation(stats : Crecto::LoadTesting::Stats)
    # Get a random ID from created records
    id_to_update = get_random_id
    return unless id_to_update

    model = Crecto::LoadTesting::TestRepo.get(Crecto::LoadTesting::LoadTestModel, id_to_update)
    return unless model

    model.value = (model.value || 0) + 1
    model.name = "Updated Load Test Item #{model.id}"

    result = Crecto::LoadTesting::TestRepo.update(model)

    if result.is_a?(Crecto::Changeset::Changeset) && !result.valid?
      raise Exception.new("Update validation failed: #{result.errors}")
    end
  end

  protected def test_delete_operation(stats : Crecto::LoadTesting::Stats)
    # Get a random ID from created records
    id_to_delete = get_random_id_for_deletion
    return unless id_to_delete

    model = Crecto::LoadTesting::TestRepo.get(Crecto::LoadTesting::LoadTestModel, id_to_delete)
    return unless model

    result = Crecto::LoadTesting::TestRepo.delete(model)

    if result.is_a?(Crecto::Changeset::Changeset) && !result.valid?
      raise Exception.new("Delete validation failed: #{result.errors}")
    end

    # Remove from created IDs
    @test_data_lock.synchronize do
      @created_ids.delete(id_to_delete)
    end
  end

  protected def test_query_operation(stats : Crecto::LoadTesting::Stats)
    # Mix of different query types
    query_type = rand(4)

    case query_type
    when 0
      # Get by ID
      id_to_get = get_random_id
      if id_to_get
        Crecto::LoadTesting::TestRepo.get(Crecto::LoadTesting::LoadTestModel, id_to_get)
      end
    when 1
      # Query with where clause
      Crecto::LoadTesting::TestRepo.all(
        Crecto::LoadTesting::LoadTestModel,
        Crecto::Repo::Query.where("value > ?", rand(1000))
      )
    when 2
      # Query with limit
      Crecto::LoadTesting::TestRepo.all(
        Crecto::LoadTesting::LoadTestModel,
        Crecto::Repo::Query.limit(10)
      )
    when 3
      # Count query
      Crecto::LoadTesting::TestRepo.aggregate(
        Crecto::LoadTesting::LoadTestModel,
        :count,
        :id
      )
    end
  end

  protected def test_association_operation(stats : Crecto::LoadTesting::Stats)
    # For basic CRUD testing, just perform a query
    # Association-specific tests are in the association load test
    test_query_operation(stats)
  end

  private def get_random_id : Int64?
    @test_data_lock.synchronize do
      @created_ids.empty? ? nil : @created_ids.sample
    end
  end

  private def get_random_id_for_deletion : Int64?
    @test_data_lock.synchronize do
      # Only delete if we have enough records left
      return nil if @created_ids.size < 10
      @created_ids.empty? ? nil : @created_ids.sample
    end
  end
end