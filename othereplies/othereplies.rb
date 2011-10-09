require 'thread' # http://stackoverflow.com/questions/5176782/uninitialized-constant-activesupportdependenciesmutex-nameerror
require 'rubygems'
require 'bundler/setup'
Bundler.require

require './user'

require './twitter-config'
# twitter-config.rb should contain something like: 
# Twitter.configure do |config|
#   config.consumer_key = "BG..."
#   config.consumer_secret = "Oj..."
# end

def deliver_tweet(user, tweet)
  template_data = {
    :id => tweet.id_str,
    :tweetURL => "http://www.twitter.com/#{tweet.user.screen_name}/statuses/#{tweet.id_str}",
    :screenName => tweet.user.screen_name,
    :realName => tweet.user.name,
    :tweetText => tweet.text,
    :source => tweet.source,
    :inReplyTo => tweet.in_reply_to_status_id_str,
    :profilePic => tweet.user.profile_image_url,
    :profileBackgroundColor => tweet.user.profile_background_color,
    :profileBackgroundImage => tweet.user.profile_use_background_image ? 'url(' + tweet.user.profile_background_image_url + ')' : 'none',
    :profileTextColor => tweet.user.profile_text_color,
    :profileLinkColor => tweet.user.profile_link_color,
    :timeStamp => tweet.created_at,
    :timeStamp_i => Time.parse(tweet.created_at).to_i,
    :utcOffset => tweet.user.utc_offset
  }
  Juggernaut.publish("/tweets/#{user.token}", template_data.to_json)
end

def refresh(user_id)
  user = User.new(user_id)
  if user.token.exists?
    user.recent_tweets do |user,tweet|
      deliver_tweet(user,tweet)
    end
  end
end

def reload_all_user_info
  User.all.each do |id| 
    u=User.new(id) 
    User.add(u.token,u.secret) 
  end
end

Thread.new { # have to run Redis subscription in a thread otherwise it blocks EventMachine
  redis = Redis::Namespace.new(:or, :redis => Redis.connect)
  redis.subscribe("usercommands") do |on|
    on.message do |type, data|
      data = JSON.parse(data)
      case data['command']
      when 'refresh'
        refresh(data['id'])
      end
    end
  end
}

if User.all.size == 0
  frequency = 300 # guess
else
  frequency = User.new(User.all.first).client.rate_limit_status.hourly_limit - 25
end

frequency = (3600.0 / frequency).ceil # per hour

EM.run do
  EventMachine::HttpRequest.use EventMachine::Middleware::JSONResponse
  EM.add_periodic_timer(frequency) {
    User.all.each do |id|
      user = User.new(id)
      EM.add_timer(frequency*rand) {
        user.next_request { |user, tweet|
          puts "[#{user.screen_name}]: #{tweet.user.screen_name}: #{tweet.text}"
          deliver_tweet(user, tweet)
        }
      }
    end
  }
end
