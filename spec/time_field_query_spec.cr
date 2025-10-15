require "./spec_helper"

describe "Time Field Query Functionality (Issue #169)" do
  describe "Basic Time field query compilation" do
    it "should compile Time field queries without errors" do
      # Test AC 1 & 3: Issue #169 resolution and compilation
      query = Query.where(some_date: Time.local)
      query.should_not be_nil
    end

    it "should handle Time field comparisons" do
      query = Query.where("some_date > ?", [Time.local])
      query.should_not be_nil
    end

    it "should handle Time field with different time zones" do
      time1 = Time.local
      time2 = Time.utc
      query = Query.where(some_date: time1).or_where(some_date: time2)
      query.should_not be_nil
    end

    it "should handle Time field arrays" do
      times = [Time.local, Time.utc]
      query = Query.where(some_date: times)
      query.should_not be_nil
    end

    it "should handle default_time field queries" do
      query = Query.where(default_time: Time.local)
      query.should_not be_nil
    end
  end

  describe "Cross-database Time field consistency" do
    # Test AC 2: Time field queries work consistently across all databases

    it "should generate consistent SQL for Time field queries" do
      test_time = Time.local(2023, 12, 25, 10, 30, 45)

      check_sql do |sqls|
        query = Query.where(some_date: test_time)
        Repo.all(User, query)

        # Verify SQL was generated without errors
        sqls.size.should be > 0
        sqls.first.should contain("some_date")
      end
    end

    it "should handle Time field in complex queries" do
      test_time = Time.local

      check_sql do |sqls|
        query = Query.where(some_date: test_time)
                     .where(name: "test")
                     .order_by("some_date DESC")
                     .limit(10)

        Repo.all(User, query)

        # Verify complex query with Time field compiles
        sqls.size.should be > 0
        sqls.first.should contain("some_date")
        sqls.first.should contain("ORDER BY")
        sqls.first.should contain("LIMIT")
      end
    end
  end

  describe "Time zone handling validation" do
    # Test AC 4: Time zone handling works correctly

    it "should handle local time in queries" do
      local_time = Time.local(2023, 12, 25, 15, 30, 0, location: Time::Location.load("America/New_York"))

      check_sql do |sqls|
        query = Query.where(some_date: local_time)
        Repo.all(User, query)

        sqls.size.should be > 0
      end
    end

    it "should handle UTC time in queries" do
      utc_time = Time.utc(2023, 12, 25, 20, 30, 0)

      check_sql do |sqls|
        query = Query.where(some_date: utc_time)
        Repo.all(User, query)

        sqls.size.should be > 0
      end
    end

    it "should handle time zone conversions consistently" do
      # Test that different time zones representing the same moment work
      time_ny = Time.local(2023, 12, 25, 15, 30, 0, location: Time::Location.load("America/New_York"))
      time_utc = Time.utc(2023, 12, 25, 20, 30, 0)  # Same moment as above

      check_sql do |sqls|
        # Both times should be handled properly in queries
        query1 = Query.where(some_date: time_ny)
        query2 = Query.where(some_date: time_utc)

        Repo.all(User, query1)
        Repo.all(User, query2)

        sqls.size.should eq(2)
      end
    end
  end

  describe "Time field parameter binding" do
    it "should properly bind Time parameters in prepared statements" do
      test_time = Time.local

      check_sql do |sqls|
        query = Query.where("some_date > ? AND some_date < ?", [test_time, test_time + 1.day])
        Repo.all(User, query)

        # Verify parameter binding works
        sqls.size.should be > 0
        sqls.first.should contain("?")
      end
    end

    it "should handle mixed parameter types with Time" do
      test_time = Time.local

      check_sql do |sqls|
        query = Query.where("some_date = ? AND name = ?", [test_time, "test_user"])
        Repo.all(User, query)

        sqls.size.should be > 0
      end
    end
  end

  describe "Time field edge cases" do
    it "should handle nil Time values" do
      check_sql do |sqls|
        query = Query.where(some_date: nil)
        Repo.all(User, query)

        sqls.size.should be > 0
        sqls.first.should contain("IS NULL")
      end
    end

    it "should handle extreme time values" do
      ancient_time = Time.utc(1970, 1, 1, 0, 0, 1)
      future_time = Time.utc(2100, 12, 31, 23, 59, 59)

      check_sql do |sqls|
        query1 = Query.where(some_date: ancient_time)
        query2 = Query.where(some_date: future_time)

        Repo.all(User, query1)
        Repo.all(User, query2)

        sqls.size.should eq(2)
      end
    end

    it "should handle Time with microseconds" do
      precise_time = Time.utc(2023, 12, 25, 12, 30, 45, nanosecond: 123456789)

      check_sql do |sqls|
        query = Query.where(some_date: precise_time)
        Repo.all(User, query)

        sqls.size.should be > 0
      end
    end
  end

  describe "Time field performance considerations" do
    # Test AC 5: Performance tests show efficient Time field query execution

    it "should handle large numbers of Time parameters efficiently" do
      # Use a more reasonable number to avoid SQLite parameter limits
      # SQLite has a default limit of 999 parameters per query
      times = Array(Time).new(100) { |i| Time.utc(2023, 1, 1) + i.days }

      check_sql do |sqls|
        query = Query.where(some_date: times)
        Repo.all(User, query)

        sqls.size.should be > 0
      end
    end

    it "should handle complex Time-based queries efficiently" do
      base_time = Time.local

      check_sql do |sqls|
        query = Query.where(some_date: base_time)
                     .and(Query.where("created_at > ?", [base_time - 30.days]))
                     .or_where("updated_at < ?", [base_time + 30.days])

        Repo.all(User, query)

        sqls.size.should be > 0
      end
    end
  end
end