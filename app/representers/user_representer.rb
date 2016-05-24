require 'roar/json/json_api'
class UserRepresenter < Roar::Decorator
  include Roar::JSON::JSONAPI

  type :user
  property :id

  property :email
  property :name
  property :occupation
end
