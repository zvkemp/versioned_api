class Api::BaseController < ApplicationController
  attr_reader :api
  before_filter :establish_api

  private

  def api_version
    @requested_version ||= params.fetch(:version).to_i
  end

  def establish_api
    api_class.version(api_version).tap do |version|
      @api = version[:delegate].new(self)
      @api_version = version[:version]
    end
  end
end
