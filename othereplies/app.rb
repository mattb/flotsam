require 'thread' # http://stackoverflow.com/questions/5176782/uninitialized-constant-activesupportdependenciesmutex-nameerror
require 'rubygems'
$KCODE='UTF8'
require 'bundler/setup'
Bundler.require

require 'user'
require 'twitter-config'
require 'uri'

class OtherApp < Sinatra::Base
  use Rack::Session::Cookie
  use OmniAuth::Builder do
    provider :twitter, Twitter.consumer_key, Twitter.consumer_secret
  end
  
  set :public, "public"

  get '/' do
    redirect '/auth/twitter'
  end

  get '/debug' do
    @users = User.all.map { |u| User.new(u) }.sort_by { |u| u.screen_name.value.downcase }
    erb :debug
  end

  get '/twitter/:token' do
    Redis::Objects.redis.publish("usercommands", { :id => params[:token], :command => 'checkin' }.to_json)

    @token = params[:token]
    @juggernaut_port = 8081
    uri = URI.parse(request.url)
    uri.port = @juggernaut_port
    uri.path = "/application.js"
    @juggernaut_url = uri.to_s
    erb :twitter
  end

  get '/twitter/:token/refresh' do
    Redis::Objects.redis.publish("usercommands", { :id => params[:token], :command => 'refresh' }.to_json)
    return 'OK'
  end

  get '/auth/twitter/callback' do
    auth = request.env['omniauth.auth']
    user = User.new(auth["credentials"]["token"])
    if !user.token.exists?
      user = User.add(auth["credentials"]["token"], auth["credentials"]["secret"])
    end
    Redis::Objects.redis.publish("usercommands", { :id => user.token.value, :command => 'setup' }.to_json)

    redirect '/twitter/' + auth["credentials"]["token"]
  end
end
