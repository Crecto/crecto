require "spec"
require "../src/crecto"

class User
  include Crecto::Schema

  schema "users" do
    field :name, :string
    field :things, :integer
    field :stuff, :integer, virtual: true
    field :nope, :float
    field :yep, :boolean
  end
end

class Tester
	include Crecto::Schema

	schema "testers" do
		field :oof, :string
	end	
end