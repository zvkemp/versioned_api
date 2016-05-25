require 'delegate'
class ErrorHandler < SimpleDelegator
  # TODO: should this go here or closer to the controller?
  def as_render_args
    { json: as_json }
  rescue Api::Errors::UnsupportedVersion => e
    error_as(e, status: 426)
  rescue ActiveRecord::RecordNotFound => e
    error_as(e, status: 404)
  rescue => e
    error_as(e)
  end

  private

  def error_as(e, status: 500, message: nil, title: nil)
    {
      status: status,
      json: {
        errors: [
          {
            status: status,
            detail: message || e.message,
            title: title || e.class.to_s
          }
        ]
      }
    }
  end
end

class Api::BaseResponder
  class << self
    def version(requested_version)
      brv = BigDecimal.new("0.#{requested_version}")
      versions.detect(-> { unsupported_version(requested_version) }) do |version:, legacy:, **|
        !legacy && brv >= version
      end
    end

    def versions
      @versions ||= [ new_version(0, parent_class: self, legacy: true) ]
    end

    def define_version(version_number, options = {}, &block)
      versions.unshift(new_version(version_number, **options, &block))
    end

    def process(*args)
      ErrorHandler.new(new(*args))
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

    def unsupported_version(requested_version)
      Api::UnsupportedVersionResponder.version(requested_version)
    end
  end

  attr_reader :api_params

  def initialize(params:, version:, http_method:, controller:, api_params:, meta: {}, **)
    @params      = params
    @api_params  = api_params.with_indifferent_access
    @version     = version
    @http_method = http_method
    @meta        = meta
    @controller  = controller
  end

  def as_json
    instance_variables.each_with_object({}) do |var, result|
      result[var.to_s] = instance_variable_get(var).as_json
    end.merge({})

    { meta: meta }
  end

  def to_json(*args)
    as_json.to_json(*args)
  end

  private

  attr_reader :controller, :version, :http_method

  def request
    controller.request
  end

  def params
    api_params.merge(request.query_parameters)
  end

  def meta
    @meta.merge({
      api_version: api_version,
      requested_version: version,
      responder: self.class.to_s,
      params: params,
      method: http_method
    })
  end
end
