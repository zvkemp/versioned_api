require 'rails_helper'

describe UserRepresenter do
  let(:user) { User.create(email: 'zk@test.com', name: 'zk', occupation: 'lazybones') }
  specify do
    binding.pry
  end
end
