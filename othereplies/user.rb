require 'thread' # http://stackoverflow.com/questions/5176782/uninitialized-constant-activesupportdependenciesmutex-nameerror
require 'rubygems'
require 'time'
require 'bundler/setup'
Bundler.require

require 'em-http/middleware/oauth'
require 'em-http/middleware/json_response'

Redis::Objects.redis = Redis::Namespace.new(:or, :redis => Redis::Objects.redis)

class User
  @@requests_in_flight = 0
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
  list :following
  set :seen
  hash_key :since_ids

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
      u.following.push(id)
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

  def next_request(&block)
    if self.following.size == 0
      return
    end

    if @@requests_in_flight > User.all.size * 1.2
      puts "Throttling [#{@@requests_in_flight}]"
      return
    end

    timeline_id = self.following.shift
    self.following.push(timeline_id)

    url = 'http://api.twitter.com/'
    path = '/1/statuses/user_timeline.json'
    params = {
      'user_id' => timeline_id
    }
    if self.since_ids.has_key?(timeline_id)
      params['since_id'] = self.since_ids[timeline_id]
    end
    #puts url
    conn = EventMachine::HttpRequest.new(url)
    conn.use EventMachine::Middleware::OAuth, { 
      :consumer_key => Twitter.consumer_key,
      :consumer_secret => Twitter.consumer_secret,
      :access_token => self.token,
      :access_token_secret => self.secret 
    }

    http = conn.get :path => path, :query => params
    http.callback do
      @@requests_in_flight -= 1
      self.filter_timeline(http.response).reverse.each { |tweet|
        block.call(self, tweet)
      }
    end
    http.errback do
      @@requests_in_flight -= 1
      puts "[#{self.screen_name}] WOE #{timeline_id}"
    end
    @@requests_in_flight += 1
  end

  def filter_timeline(tweets)
    max_tweet_id = 0
    user_id = 0
    tweets = tweets.map { |tweet| Hashie::Mash.new(tweet) }.select { |tweet|
      max_tweet_id = [max_tweet_id, tweet.id].max
      user_id = tweet.user.id
      wanted = (!tweet.in_reply_to_user_id.nil? and !seen?(tweet.id) and !following.include?(tweet.in_reply_to_user_id.to_s))
    }.map { |tweet|
      timeline.add(tweet.to_json, Time.parse(tweet.created_at).to_i)
      tweet
    }
    if max_tweet_id != 0 and user_id != 0
      self.timeline.remrangebyrank(0,-50) # keep it down to 50 items
      self.since_ids[user_id] = max_tweet_id
    end
    return tweets
  end

  def recent_tweets(&block)
    self.timeline.revrange(0,10).reverse.each { |json| block.call(self,Hashie::Mash.new(JSON.parse(json))) }
  end
end
