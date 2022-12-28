require 'google/api_client/client_secrets'
require 'redis'
require 'sinatra/base'
require 'sinatra/reloader'
require 'google/apis/gmail_v1'
require 'securerandom'

Gmail = Google::Apis::GmailV1
class WebApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  enable :sessions
  set :session_secret, SecureRandom.hex(32)

  get '/' do
    redirect to('/oauth2callback') unless session.has_key?(:credentials)
    client_opts = JSON.parse(session[:credentials])
    auth_client = Signet::OAuth2::Client.new(client_opts)

    gmail = ::Gmail::GmailService.new
    gmail.authorization = auth_client

    user = gmail.get_user_profile('me').email_address
    newSendAs = Gmail::SendAs.new
    newSendAs.send_as_email = user
    newSendAs.signature = ENV['NEW_SIGNATURE']
    newSendAs.is_primary = true
    newSendAs.is_default = true
    gmail.patch_user_setting_send_as('me', user, newSendAs, options: {})
    'OK'
  end

  get '/oauth2callback' do
    client_secrets = Google::APIClient::ClientSecrets.load(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
    auth_client = client_secrets.to_authorization
    auth_client.update!(
      scope: ['https://www.googleapis.com/auth/gmail.settings.basic', 'https://www.googleapis.com/auth/gmail.readonly'],
      redirect_uri: url('/oauth2callback')
    )
    if request['code'].nil?
      auth_uri = auth_client.authorization_uri.to_s
      redirect to(auth_uri)
    else
      auth_client.code = request['code']
      auth_client.fetch_access_token!
      auth_client.client_secret = nil
      session[:credentials] = auth_client.to_json
      redirect to('/')
    end
  end
end
