class Api::UnsupportedVersionResponder < Api::BaseResponder
  class << self
    def versions
      @versions ||= [ new_version(0, parent_class: self, legacy: true) ]
    end

    def version(requested_version)
      versions.first
    end

    private

    def unsupported_version(*)
      raise 'recursion halted'
    end
  end

  def as_json
    raise Api::Errors::UnsupportedVersion
  end
end
