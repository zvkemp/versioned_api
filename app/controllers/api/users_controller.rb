require 'trailblazer/operation/representer'
require 'trailblazer/operation/controller'
require 'trailblazer/operation/collection'
require 'trailblazer/operation/model'
require 'pry'

class Api::UsersController < ApplicationController
  respond_to :json
  def index
    binding.pry
    render json: UserIndex.present(params).to_json
  end

  def show
    render json: UserShow.present(params).to_json
  end

  class UserShow < Trailblazer::Operation
    include Trailblazer::Operation::Representer
    include Trailblazer::Operation::Model

    model User, :find

    representer(UserRepresenter)
  end

  class UserIndex < Trailblazer::Operation
    include Trailblazer::Operation::Collection
    include Trailblazer::Operation::Model
    include Trailblazer::Operation::Representer

    representer(UserRepresenter.for_collection)

    def model!(params)
      User.all
    end
  end
end
