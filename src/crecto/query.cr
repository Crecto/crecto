module Crecto
  module Repo
    alias WhereType = Hash(Symbol, PkeyValue) | Hash(Symbol, DbValue) | Hash(Symbol, Array(DbValue)) | Hash(Symbol, Array(PkeyValue)) | Hash(Symbol, Array(Int32)) | Hash(Symbol, Array(Int64)) | Hash(Symbol, Array(String)) | Hash(Symbol, Int32 | String) | Hash(Symbol, Int32) | Hash(Symbol, Int64) | Hash(Symbol, String) | Hash(Symbol, Int32 | Int64 | String | Nil) | NamedTuple(clause: String, params: Array(DbValue | PkeyValue))

    # Queries are used to retrieve and manipulate data from a repository.  Syntax is much like that of ActiveRecord:
    #
    # `Query.select('id').where(name: "fred").join(Post, where: {name: "this post"}).order_by("users.name").limit(1).offset(4)`
    #
    class Query
      property selects : Array(String)
      property wheres = [] of WhereType
      property or_wheres = [] of WhereType
      property joins = [] of Symbol
      property preloads = [] of Symbol
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
      def self.where(where_string : String, params : Array(DbValue | PkeyValue))
        self.new.where(where_string, params)
      end

      # Query where with a Symbol and DbValue
      def self.where(where_sym : Symbol, param : DbValue)
        self.new.where(where_sym, param)
      end

      def self.where(where_sym : Symbol, params : Array(DbValue | PkeyValue))
        self.new.where(where_sym, params)
      end

      # Key => Value pair(s) used in query `OR WHERE`
      def self.or_where(**or_wheres)
        self.new.or_where(**or_wheres)
      end

      # TODO: not done yet
      def self.join(klass, joins)
        self.new.join(klass, joins)
      end

      def self.preload(preload_associations : Array(Symbol))
        self.new.preload(preload_associations)
      end

      def self.preload(preload_association : Symbol)
        self.new.preload(preload_association)
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
        # w = {} of Symbol => DbValue | PkeyValue | Array(DbValue | PkeyValue)
        # w[wheres.first_key] = wheres.first_value.as(DbValue | PkeyValue | Array(DbValue | PkeyValue))
        @wheres.push(Hash.zip(wheres.keys, wheres.values))
        self
      end

      def where(where_string : String, params : Array(DbValue))
        @wheres.push({clause: where_string, params: params.map { |p| p.as(DbValue) }})
        self
      end

      def where(where_sym : Symbol, param : DbValue)
        @wheres.push(Hash.zip([where_sym], [param]))
        self
      end

      def where(where_sym : Symbol, params : Array(DbValue))
        w = {} of Symbol => Array(DbValue)
        w[where_sym] = params.map { |x| x.as(DbValue) }
        @wheres.push(w)
        self
      end

      def or_where(**or_wheres)
        or_wheres = or_wheres.to_h
        @or_wheres.push or_wheres
        self
      end

      # :nodoc:
      def join(klass, joins)
        @join = {klass: klass, joins: joins}
        self
      end

      def preload(preload_associations : Array(Symbol))
        @preloads += preload_associations
        self
      end

      def preload(preload_association : Symbol)
        @preloads.push(preload_association)
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
