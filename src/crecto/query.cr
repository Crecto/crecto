module Crecto
  module Repo
    # Queries are used to retrieve and manipulate data from a repository.  Syntax is much like that of ActiveRecord:
    #
    # `Query.select('id').where(name: "fred").join(Post, where: {name: "this post"}).order_by("users.name").limit(1).offset(4)`
    #
    class Query
      property selects : Array(String)
      property wheres = [] of Hash(Symbol, Int32) | Hash(Symbol, String) | Hash(Symbol, Array(Int32)) | Hash(Symbol, Array(String)) | Hash(Symbol, Int32 | String) | NamedTuple(clause: String, params: Array(DbValue))
      property joins = [] of Hash(Symbol, Hash(Symbol, String | Array(String)))
      property order_bys = [] of String
      property limit : Int32?
      property offset : Int32?

      # Fields to select, separated by comma.  Default is "*"
      def self.select(selects)
        self.new.select("*")
      end

      # Key => Value pair(s) used in query `WHERE`
      def self.where(**wheres)
        self.new.where(**wheres)
      end

      # Query where with a string (i.e. `.where("users.id > 10"))
      def self.where(where_string : String, params : Array(DbValue))
        self.new.where(where_string, params)
      end

      # TODO: not done yet
      def self.join(klass, joins)
        self.new.join(klass, joins)
      end

      # Field to order by
      def self.order_by(order : String)
        self.new.order_by(order)
      end

      # Query Limit
      def self.limit(lim : Int32 | Int64)
        self.new.limit(lim)
      end

      # Query offset
      def self.offset(off : Int32 | Int64)
        self.new.offset(off)
      end

      def initialize
        @selects = ["*"]
      end

      # :nodoc:
      def select(selects)
        @selects = string
        self
      end

      # :nodoc:
      def where(**wheres)
        wheres = wheres.to_h
        @wheres.push wheres
        self
      end

      def where(where_string : String, params : Array(DbValue))
        @wheres.push({clause: where_string, params: params.map{|p| p.as(DbValue)}})
        self
      end

      # :nodoc:
      def join(klass, joins)
        @join = {klass: klass, joins: joins}
        self
      end

      # :nodoc:
      def order_by(order)
        @order_bys.push(order)
        self
      end

      # :nodoc:
      def limit(lim)
        @limit = limit
        self
      end

      # :nodoc:
      def offset(off)
        @offset = off
        self
      end
    end
  end
end

