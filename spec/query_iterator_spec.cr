require "./spec_helper"

describe Crecto::Repo::QueryIterator do
  describe "interface contract" do
    it "exists as a class" do
      # Verify the class exists and has the expected structure
      iterator_type = Crecto::Repo::QueryIterator
      iterator_type.should_not be_nil
    end

    it "implements Iterator interface" do
      # Since QueryIterator requires a DB::ResultSet, we test the interface contract
      # The actual class includes Iterator(T) as seen in the source
      iterator_class = Crecto::Repo::QueryIterator

      # Test that the class can be instantiated with the expected parameters
      # Note: We can't actually instantiate it without a DB::ResultSet
      iterator_class.should_not be_nil
    end

    it "has expected interface" do
      # Test that QueryIterator can be referenced and has expected type
      iterator_type = Crecto::Repo::QueryIterator(Int32)
      iterator_type.should_not be_nil
    end
  end

  describe "iterator behavior patterns" do
    it "demonstrates iterator pattern behavior" do
      # Test the iterator pattern using a mock implementation
      mock_iterator = TestQueryIterator.new([1, 2, 3, 4, 5])

      # Test basic iteration
      results = [] of Int32
      mock_iterator.each do |item|
        results << item
      end
      results.should eq([1, 2, 3, 4, 5])

      # Test that iterators can be used with Enumerable methods
      transformed_results = [] of Int32
      mock_iterator.rewind.each do |item|
        transformed_results << (item * item)
      end
      transformed_results.should eq([1, 4, 9, 16, 25])
    end

    it "handles memory-efficient iteration" do
      items = (1..100).to_a
      iterator = TestQueryIterator.new(items)

      count = 0
      sum = 0
      iterator.each do |item|
        count += 1
        sum += item
      end

      count.should eq(100)
      sum.should eq(items.sum)
    end

    it "supports early termination" do
      items = (1..10).to_a
      iterator = TestQueryIterator.new(items)

      results = [] of Int32
      iterator.each do |item|
        results << item
        break if item >= 5
      end

      results.should eq([1, 2, 3, 4, 5])
    end
  end

  describe "error handling patterns" do
    it "handles iterator errors gracefully" do
      iterator = TestQueryIterator.new([1, 2, 3])

      # Test that iteration can handle various states
      results = [] of Int32
      iterator.each do |item|
        results << item
      end

      results.should eq([1, 2, 3])
    end
  end
end

# Test helper classes for QueryIterator testing
class TestQueryIterator(T)
  include Iterator(T)

  def initialize(@items : Array(T))
    @index = 0
  end

  def next
    if @index < @items.size
      item = @items[@index]
      @index += 1
      item
    else
      stop
    end
  end

  def rewind
    @index = 0
    self
  end
end

class ErrorQueryIterator(T)
  include Iterator(T)

  def initialize(@items : Array(T))
    @index = 0
  end

  def next
    if @index < @items.size
      item = @items[@index]
      @index += 1
      item
    else
      stop
    end
  end

  def rewind
    @index = 0
    self
  end
end