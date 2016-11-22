require "spec"
require "../src/crecto"

class User
  include Crecto::Schema

  schema "users" do
    field :name, String
    field :things, Int32
    field :stuff, Int32, virtual: true
    field :nope, Float64
    field :yep, Bool
    has_many :users
    has_one :thing
    belongs_to :stuff
  end
end

class Tester
	include Crecto::Schema

	schema "testers" do
		field :oof, String
	end	
end