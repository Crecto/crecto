require "./spec_helper"

describe Crecto::BulkConfig do
  describe ".instance" do
    it "returns the same instance" do
      config1 = Crecto::BulkConfig.instance
      config2 = Crecto::BulkConfig.instance
      config1.should be(config2)
    end

    it "creates a singleton instance" do
      config = Crecto::BulkConfig.instance
      config.should be_a(Crecto::BulkConfig)
    end
  end

  describe "default values" do
    it "has correct default configuration values" do
      config = Crecto::BulkConfig.instance

      config.postgres_copy_threshold.should eq(2000)
      config.mysql_load_threshold.should eq(1000)
      config.sqlite_batch_size.should eq(200)
      config.default_batch_size.should eq(1000)
      config.max_bulk_changesets.should eq(10_000)
      config.bulk_timeout.should eq(300)
    end
  end

  describe "configuration properties" do
    it "allows changing postgres_copy_threshold" do
      config = Crecto::BulkConfig.instance
      config.postgres_copy_threshold = 5000
      config.postgres_copy_threshold.should eq(5000)
    end

    it "allows changing mysql_load_threshold" do
      config = Crecto::BulkConfig.instance
      config.mysql_load_threshold = 2500
      config.mysql_load_threshold.should eq(2500)
    end

    it "allows changing sqlite_batch_size" do
      config = Crecto::BulkConfig.instance
      config.sqlite_batch_size = 500
      config.sqlite_batch_size.should eq(500)
    end

    it "allows changing default_batch_size" do
      config = Crecto::BulkConfig.instance
      config.default_batch_size = 2000
      config.default_batch_size.should eq(2000)
    end

    it "allows changing max_bulk_changesets" do
      config = Crecto::BulkConfig.instance
      config.max_bulk_changesets = 20_000
      config.max_bulk_changesets.should eq(20_000)
    end

    it "allows changing bulk_timeout" do
      config = Crecto::BulkConfig.instance
      config.bulk_timeout = 600
      config.bulk_timeout.should eq(600)
    end
  end

  describe "singleton behavior" do
    it "persists changes across instance access" do
      config1 = Crecto::BulkConfig.instance
      config1.postgres_copy_threshold = 3000

      config2 = Crecto::BulkConfig.instance
      config2.postgres_copy_threshold.should eq(3000)
    end
  end
end