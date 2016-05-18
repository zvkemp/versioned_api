require 'rails_helper'

describe Api::UsersController do
  let(:params) { { version: version, format: :json } }

  let(:response_body) do
    make_request
    JSON.parse(response.body)
  end
  let(:metadata) { response_body['metadata'] }

  def match_hash(hash)
    match(hash_including(hash))
  end

  describe 'index' do
    let(:make_request) { get :index, params }

    context 'v0' do
      let(:version) { 0 }

      specify { expect(response_body).to match_hash({ 'users' => [] }) }
      specify { expect(metadata).to match_hash({ 'api_version' => 0 }) }
    end

    context 'v2016' do
      let(:version) { 2016 }

      it 'returns the latest version from 2015' do
        expect(metadata).to match_hash({ 'api_version' => 201505 })
      end
    end

    context 'with users' do
      let(:users) { response_body['users'] }
      let(:user_data) do
        [
          ['Ms. Priscilla Bins', 'priscilla_bins_ms@oconner.biz'],
          ['Llewellyn Runolfsdottir', 'runolfsdottir.llewellyn@roob.com']
        ]
      end

      before do
        user_data.each do |name, email|
          User.create(name: name, email: email)
        end
      end

      context 'v201602' do
        let(:version) { 201602 }
        specify do
          expect(users.count).to eq(2)
          expect(users.first.key?("type")).to eq(false)
        end
      end

      context 'v201602201111111' do
        let(:version) { 201602201111111 }
        specify do
          expect(users.count).to eq(2)
          expect(users.first.key?("type")).to eq(true)
          expect(metadata['api_version']).to eq(20160216)
        end
      end
    end
  end
end
