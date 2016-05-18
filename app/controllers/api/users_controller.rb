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

module Api
  module UserAPI
    class << self
      def version(requested_version)
        brv = BigDecimal.new("0.#{requested_version}")
        versions.detect(-> { raise "Unsupported API version #{requested_version}" }) do |version:, legacy:, **|
          !legacy && brv >= version
        end
      end

      def versions
        @versions ||= [ new_version(0, parent_class: Base, legacy: true) ]
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

    class Base
      attr_reader :controller, :deprecated

      def initialize(controller, deprecated: false, **)
        @controller = controller
        @deprecated = deprecated
      end

      def index
        { users: users, metadata: metadata }
      end

      def show
        serialize User.find(params[:id])
      end

      private

      def users
        User.all.map(&method(:serialize))
      end

      def metadata
        {
          requested_version: controller.instance_variable_get(:@requested_version),
          api_version: api_version
        }.merge(deprecation_notice)
      end

      def serialize(user)
        user.attributes.slice(*%w(id name email occupation))
      end

      def params
        controller.params
      end

      def deprecation_notice
        return {} unless deprecated
        { deprecation_warning: "#{self.class} api_version is deprecated." }
      end
    end
  end
end

Api::UserAPI.define_version(201405, deprecated: true) do
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
    { id: user.id, attributes: super }
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
