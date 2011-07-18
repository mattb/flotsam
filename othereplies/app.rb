require 'thread' # http://stackoverflow.com/questions/5176782/uninitialized-constant-activesupportdependenciesmutex-nameerror
require 'rubygems'
$KCODE='UTF8'
require 'bundler/setup'
Bundler.require

require 'user'
require 'twitter-config'

class OtherApp < Sinatra::Base
  use Rack::Session::Cookie
  use OmniAuth::Builder do
    provider :twitter, Twitter.consumer_key, Twitter.consumer_secret
  end
  
  set :public, "public"

  get '/' do
    redirect '/auth/twitter'
  end

  get '/twitter/:token' do
    @token = params[:token]
    erb :twitter
  end

  get '/auth/twitter/callback' do
    auth = request.env['omniauth.auth']
    user = User.new(auth["credentials"]["token"])
    if !user.name.exists?
      user = User.add(auth["credentials"]["token"], auth["credentials"]["secret"])
    end
    Redis::Objects.redis.publish("usercommands", { :id => user.token.value }.to_json)

    redirect '/twitter/' + auth["credentials"]["token"]
  end
end
