class User < ActiveRecord::Base
  def as_json(*args)
    UserRepresenter.new(self).as_json
  end
end
