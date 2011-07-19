require 'thread' # http://stackoverflow.com/questions/5176782/uninitialized-constant-activesupportdependenciesmutex-nameerror
require 'rubygems'
require 'time'
$KCODE='UTF8'
require 'bundler/setup'
Bundler.require

require 'em-http/middleware/oauth'
require 'em-http/middleware/json_response'

Redis::Objects.redis = Redis::Namespace.new(:or, :redis => Redis::Objects.redis)

class User
  include Redis::Objects
  def initialize(id) @id = id end
  def id; @id; end

  value :name
  value :screen_name
  value :token
  value :secret
  value :twitter_id
  value :icon
  sorted_set :timeline
  set :following
  set :seen

  def User.all
    Redis::Objects.redis.smembers("users")
  end

  def User.add(token, secret)
    client = Twitter::Client.new :oauth_token => token, :oauth_token_secret => secret
    data = client.user

    u = User.new(token)
    u.screen_name = data.screen_name
    u.token = token
    u.secret = secret
    u.name = data.name
    u.twitter_id = data.id
    u.icon = data.profile_image_url
    u.following.clear
    client.friend_ids.ids.each { |id|
      u.following.add(id)
    }

    Redis::Objects.redis.sadd("users",token)
    return u
  end

  def seen?(tweet_id)
    result = seen.include?(tweet_id)
    if !result
      seen.add(tweet_id)
    end
    return result
  end

  def client
    @client ||= Twitter::Client.new :oauth_token => token, :oauth_token_secret => secret
  end

  def schedule_calls(scheduler, &block)
    scheduler.find_by_tag(self.token.value).each { |job|
      job.unschedule
    }

    rates = self.client.rate_limit_status

    following_count = self.following.size
    frequency = (following_count.to_f / (rates.hourly_limit - 25)).ceil # how many hours we should take to cycle through all the IDs without busting the rate limit.

    self.following.get.sort_by { rand }.each_with_index { |id, idx|
      scheduler.every(frequency.to_s + "h", :blocking => true, :first_in => ((frequency*60.0*60.0/following_count)*idx).to_i.to_s + "s", :tags => self.token.value) do
        EventMachine::HttpRequest.use EventMachine::Middleware::JSONResponse
        conn = EventMachine::HttpRequest.new('https://api.twitter.com/1/statuses/user_timeline.json?user_id='+id)
        conn.use EventMachine::Middleware::OAuth, { :consumer_key => Twitter.consumer_key,
                                                    :consumer_secret => Twitter.consumer_secret,
                                                    :access_token => self.token,
                                                    :access_token_secret => self.secret }

        http = conn.get
        http.callback do
          self.filter_timeline(http.response).each { |tweet|
            block.call(self, tweet)
          }
        end
        http.errback do
          puts "[self.screen_name] WOE #{id}"
        end

      end
    }
  end

  def filter_timeline(tweets)
    tweets = tweets.map { |tweet| Hashie::Mash.new(tweet) }.select { |tweet|
      wanted = (!tweet.in_reply_to_user_id.nil? and !seen?(tweet.id) and !following.include?(tweet.in_reply_to_user_id))
    }.map { |tweet|
      timeline.add(tweet.to_json, Time.parse(tweet.created_at).to_i)
      tweet
    }
    timeline.remrangebyrank(0,-50) # keep it down to 50 items
    return tweets
  end

  def recent_tweets(&block)
    self.timeline.range(0,10).each { |json| block.call(self,Hashie::Mash.new(JSON.parse(json))) }
  end
end
