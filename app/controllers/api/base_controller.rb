class Api::BaseController < ApplicationController
  respond_to :json

  def perform
    render api_object.as_render_args
  end

  private

  def api_object
    p = params[:path]
    rr = Api::Router.route_set.recognize_path(p, env).with_indifferent_access

    # TODO: possibility of unwanted recursion here
    Api::Router.from_params(params, api_params: rr, controller: self)
  rescue => e
    Api::Router.from_params(params, api_params: { error: e.message }, controller: self)
    # render json: { error: e }
  end

  def api_params
  end
end
