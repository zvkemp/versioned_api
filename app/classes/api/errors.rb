module Api::Errors
  class Error < ::StandardError
  end

  class UnsupportedVersion < Error
  end
end
