require 'google/api_client/client_secrets'
require 'redis'
require 'sinatra/base'
require 'sinatra/reloader'
require 'google/apis/gmail_v1'
require 'securerandom'
require 'erb'

Gmail = Google::Apis::GmailV1
class WebApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  enable :sessions
  set :session_secret, ENV['SESSION_SECRET'] || SecureRandom.hex(32)
  # rubocop:disable all
  def index_content(signature, notice = nil, error = nil)
    c = <<-EOS
<html>
  <head>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-MrcW6ZMFYlzcLA8Nl+NtUVF0sA7MsXsP1UyJoMp4YLEuNSfAP+JcXn/tWtIaxVXM" crossorigin="anonymous"></script>
  </head>
  <body>
    <div class="container">
       <h1>君の本気の署名を見せてくれ</h1>
       <% if notice %>
       <div class="alert alert-primary" role="alert">
         <%= notice %>
       </div>
       <% end %>

       <% if error %>
       <div class="alert alert-danger" role="alert">
         <%= error %>
       </div>
       <% end %>

       <form class="row g-3" action="/" method="post">
         <div class="mb-3">
           <label for="signature" class="form-label">署名</label>
           <textarea class="form-control" name="signature" id="signature" rows="20"><%= signature %></textarea>
         </div>
         <div class="col-auto">
           <button type="submit" class="btn btn-primary mb-3">保存</button>
         </div>
       </form>
     </div>
  </body>
<html>
    EOS
    email = client.get_user_profile('me').email_address
    ERB.new(c, trim_mode: '-').result(binding)
  end
  # rubocop:enable all

  get '/' do
    redirect to('/oauth2callback') unless session.has_key?(:credentials)
    index_content(ENV['DEFAULT_SIGNATURE'])
  end

  def gmail
    client_opts = JSON.parse(session[:credentials])
    auth_client = Signet::OAuth2::Client.new(client_opts)
    gmail = ::Gmail::GmailService.new
    gmail.authorization = auth_client
  end

  post '/' do
    redirect to('/oauth2callback') unless session.has_key?(:credentials)
    client = gmail
    user = client.get_user_profile('me').email_address
    new_send_as = Gmail::SendAs.new
    new_send_as.send_as_email = user
    new_send_as.signature = params['signature']
    new_send_as.is_primary = true
    new_send_as.is_default = true
    client.patch_user_setting_send_as('me', user, new_send_as, options: {})
    index_content(params['signature'], '正常に保存しました')
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
