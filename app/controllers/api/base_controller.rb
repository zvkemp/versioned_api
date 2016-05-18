class Api::BaseController < ApplicationController
  attr_reader :api
  before_filter :establish_api

  private

  def api_version
    @requested_version ||= params.fetch(:version).to_i
  end

  def establish_api
    api_class.version(api_version).tap do |version|
      @api = version[:delegate].new(self, **version)
      @api_version = version[:version]
    end
  rescue => e
    render json: { error: e.message }, status: 500 and return false
  end
end
