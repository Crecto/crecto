module Crecto
  module Repo
    class Query
      property selects : Array(String)
      property wheres : (Hash(Symbol, Int32) | Hash(Symbol, Int32 | String) | Hash(Symbol, Array(String | Int32)))?
      property joins : (Hash(Symbol, Hash(Symbol, String | Array(String))))?
      property order_by : String?
      property limit : (Int32 | Int64)?
      property offset : (Int32 | Int64)?

      def self.select(selects)
        self.new.select("*")
      end

      def self.where(**wheres)
        self.new.where(**wheres)
      end

      def self.join(klass, joins)
        self.new.join(klass, joins)
      end

      def self.order_by(order : String)
        self.new.order_by(order)
      end

      def self.limit(lim : Int32 | Int64)
        self.new.limit(lim)
      end

      def self.offset(off : Int32 | Int64)
        self.new.offset(off)
      end

      def initialize
        @selects = ["*"]
      end

      def select(selects)
        @selects = string
        self
      end

      def where(**wheres)
        wheres = wheres.to_h
        @wheres = wheres
        self
      end

      def join(klass, joins)
        @join = {klass: klass, joins: joins}
        self
      end

      def order_by(order)
        @order_by = order
        self
      end

      def limit(lim)
        @limit = limit
        self
      end

      def offset(off)
        @offset = off
        self
      end
    end
  end
end

# SELECT id, name, * FROM users
#   INNER_JOIN posts ON posts.user_id=user.id
#   WHERE users.id=8
#   ORDER BY users.name
#   LIMIT 1
#   OFFSET 40

# * selects (default *)
# * where
# * joins
#   * where
# * order_by
# * limit
# * offset

# Query.select('id').where(name: "fred").join(Post, where: {name: "this post"}).order_by("users.name").limit(1).offset(4)

