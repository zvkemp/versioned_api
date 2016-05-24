class Api::Router
  MATCH_KEYWORDS = %i(version http_method params)

  class << self
    def route_set
      @route_set ||= ActionDispatch::Routing::RouteSet.new
    end

    def matches
      @matches ||= {
        "api/user_responder" => Api::UserResponder,
        "api/foos_responder" => Api::FoosResponder
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
    version[:delegate].new(**args)
  end
end

# truncate json output
module AsJSONFlopper
  def as_json(*)
    instance_variables.each_with_object({}) do |var, result|
      result[var.to_s] = instance_variable_get(var).to_s.truncate(100)
    end
  end
end

class Api::BaseResponder
  class << self
    def version(requested_version)
      brv = BigDecimal.new("0.#{requested_version}")
      versions.detect(-> { raise "Unsupported API version #{requested_version}" }) do |version:, legacy:, **|
        !legacy && brv >= version
      end
    end

    def versions
      @versions ||= [ new_version(0, parent_class: self, legacy: true) ]
    end

    def define_version(version_number, options = {}, &block)
      versions.unshift(new_version(version_number, **options, &block))
    end

    private

    def new_version(version_number, deprecated: false, legacy: false, parent_class: nil, &block)
      bvd = BigDecimal.new("0.#{version_number}")
      parent_class ||= versions.detect(-> { raise ArgumentError }) { |version:, **| bvd > version }[:delegate]

      new_class = Class.new(parent_class).tap do |klass|
        klass.class_eval { define_method(:api_version) { version_number } }
        klass.class_eval(&block) if block
        const_set("V#{version_number}", klass)
      end

      { version: bvd, delegate: new_class, deprecated: deprecated, legacy: legacy }
    end
  end

  attr_reader :api_params

  def initialize(params:, version:, http_method:, controller:, api_params:, **meta)
    @params      = params
    @api_params  = api_params.with_indifferent_access
    @version     = version
    @http_method = http_method
    @meta        = meta
    @controller  = controller.tap do |c|
      c.extend(AsJSONFlopper)
    end
  end

  def as_json
    instance_variables.each_with_object({}) do |var, result|
      result[var.to_s] = instance_variable_get(var).as_json
    end.merge({
      responder: self.class.to_s,
      api_version: api_version
    })
  end

  def to_json(*args)
    as_json.to_json(*args)
  end

  def params
    @params.merge(api_params) # todo: query string belongs to params instead of api params
  end
end

class Api::EchoResponder < Api::BaseResponder
end

class Api::UserResponder < Api::BaseResponder
  def as_json(*args)
    super.merge(response_for_action.call)
  end

  def response_for_action
    {
      'index' => -> { representer.for_collection.new(User.limit(params[:limit])) },
      'show'  => -> { representer.new(User.find(api_params[:id])) }
    }[api_params[:action]]

  end

  def representer
    UserRepresenter
  end
end

class Api::FoosResponder < Api::BaseResponder
end

Api::EchoResponder.define_version(1)    {}
Api::UserResponder.define_version(2014, deprecated: true) {}
Api::UserResponder.define_version(2015) {}
Api::FoosResponder.define_version(2015) {}

# necessary to get router to recognize the non-controller thingies
# should be able to remove this eventually.
Api::FoosResponderController = Api::FoosResponder
Api::UserResponderController = Api::UserResponder

Api::Router.route_set.draw do
  resources :users, controller: Api::UserResponder
  resources :foos, controller: Api::FoosResponder
end
