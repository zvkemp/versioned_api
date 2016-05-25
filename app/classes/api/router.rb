class Api::Router
  MATCH_KEYWORDS = %i(version http_method params)

  class << self
    def route_set
      @route_set ||= ActionDispatch::Routing::RouteSet.new
    end

    def matches
      @matches ||= {
        "api/user_responder" => Api::UserResponder,
        # "api/foos_responder" => Api::FoosResponder
      }
    end
  end

  def self.from_params(params, api_params:, controller:)
    args              = params.slice(*MATCH_KEYWORDS).symbolize_keys
    args[:controller] = controller
    args[:http_method] = controller.request.method
    args[:params]     = params.except(*MATCH_KEYWORDS)
    args[:api_params] = api_params

    responder = matches.fetch(api_params[:controller], Api::EchoResponder)
    version = responder.version(params[:version])

    args[:meta] = version.except(:delegate) # probably not necessary
    version[:delegate].process(**args)
  end
end

Api::EchoResponder.define_version(1)    {}

Api::UserResponder.define_version(2014, deprecated: true) do

  def as_json(*args)
    super.merge(response_as_json)
  end

  private

  def response_as_json
    { data: response_for_action.call.as_json }
  end

  def response_for_action
    {
      'index' => -> { User.limit(params[:limit]) },
      'show'  => -> { User.find(api_params[:id]) }
    }[action]
  end

  def action
    api_params[:action]
  end
end

Api::UserResponder.define_version(2015) do

  private

  def response_as_json
    response_for_action.call.as_json
  end

  def response_for_action
    {
      'index' => -> { representer.for_collection.new(super.call) },
      'show'  => -> { representer.new(super.call) }
    }[action]
  end

  def representer
    UserRepresenter
  end
end

# necessary to get router to recognize the non-controller thingies
# should be able to remove this eventually.
Api::UserResponderController = Api::UserResponder

Api::Router.route_set.draw do
  resources :users, controller: Api::UserResponder
end
