require 'delegate'
class Api::UsersController < Api::BaseController
  def index
    render json: api.index
  end

  def show
    render json: api.show
  end

  private

  def api_class
    Api::UserAPI
  end

  def method_missing(name, *args, &block)
    api.send(name, *args, &block)
  end
end

module Api::UserAPI
  class Base
    attr_reader :controller

    def initialize(controller)
      @controller = controller
    end

    def index
      {
        users: users,
        metadata: metadata
      }
    end

    def show
      serialize User.find(params[:id])
    end

    def api_version
      0
    end

    private

    def users
      User.all.map(&method(:serialize))
    end

    def metadata
      {
        requested_version: controller.instance_variable_get(:@requested_version),
        api_version: api_version
      }
    end

    def serialize(user)
      user.attributes.slice(*%w(id name email))
    end

    def params
      controller.params
    end
  end

  def self.version(requested_version)
    brv = BigDecimal.new("0.#{requested_version}")
    versions.detect {|version:, **| brv >= version }
  end

  class << self
    def versions
      @versions ||= [ { version: 0, delegate: Base } ]
    end

    def define_version(new_version, &block)
      base_version = versions.detect(-> { raise ArgumentError }) { |version:, **| new_version > version }
      versions.unshift({
        version: BigDecimal.new("0.#{new_version}"),
        delegate: Class.new(base_version[:delegate]).tap do |klass|

          klass.class_eval do
            define_method(:api_version) { new_version }
          end

          klass.class_eval(&block)
          const_set("V#{new_version}", klass)
        end
      })
    end
  end
end


Api::UserAPI.define_version(201405) do
  private

  def users
    User.all.each_with_object({}) do |user, acc|
      acc[user.id] = serialize(user)
    end
  end
end

Api::UserAPI.define_version(201505) do
  private

  def metadata
    super.merge(timestamp: Time.now, delegate: self.class.name)
  end
end

Api::UserAPI.define_version(201602) do
  private

  def users
    User.limit(params[:limit]).map(&method(:serialize))
  end

  def serialize(user)
    { id: user.id, attributes: user.attributes }
  end
end

Api::UserAPI.define_version(20160216) do
  private

  def users
    User.limit(params[:limit]).map(&method(:serialize))
  end

  def serialize(user)
    { id: user.id, type: :user, attributes: user.attributes }
  end
end

Api::UserAPI.define_version(201603) do
  def show
    {
      user: super,
      metadata: metadata
    }
  end
end
