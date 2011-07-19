require 'thread' # http://stackoverflow.com/questions/5176782/uninitialized-constant-activesupportdependenciesmutex-nameerror
require 'rubygems'
$KCODE='UTF8'
require 'bundler/setup'
Bundler.require
include Twitter::Autolink

require 'user'

require 'twitter-config'
# twitter-config.rb should contain something like: 
# Twitter.configure do |config|
#   config.consumer_key = "BG..."
#   config.consumer_secret = "Oj..."
# end

TWEET_TEMPLATE =<<NYAN
<!-- {{{tweetURL}}} -->
<style type='text/css'>.bbpBox{{id}} {background-image:{{{profileBackgroundImage}}}; background-color: \#{{{profileBackgroundColor}}};padding:20px;} p.bbpTweet{background:#fff;padding:10px 12px 10px 12px;margin:0;min-height:48px;color:#000;font-size:18px !important;line-height:22px;-moz-border-radius:5px;-webkit-border-radius:5px} p.bbpTweet span.metadata{display:block;width:100%;clear:both;margin-top:8px;padding-top:12px;height:40px;border-top:1px solid #fff;border-top:1px solid #e6e6e6} p.bbpTweet span.metadata span.author{line-height:19px} p.bbpTweet span.metadata span.author img{float:left;margin:0 7px 0 0px;width:38px;height:38px} p.bbpTweet a:hover{text-decoration:underline}p.bbpTweet span.timestamp{font-size:12px;display:block}</style>
<div class='bbpBox{{id}}'><p class='bbpTweet'>{{{tweetText}}}<span class='timestamp'><a title='{{timeStamp}}' href='{{{tweetURL}}}'>{{{timeStamp}}}</a> via {{{source}}} <a href='http://twitter.com/intent/favorite?tweet_id={{id}}'><img src='http://si0.twimg.com/images/dev/cms/intents/icons/favorite.png' /> Favorite</a> <a href='http://twitter.com/intent/retweet?tweet_id={{id}}'><img src='http://si0.twimg.com/images/dev/cms/intents/icons/retweet.png' /> Retweet</a> <a href='http://twitter.com/intent/tweet?in_reply_to={{id}}'><img src='http://si0.twimg.com/images/dev/cms/intents/icons/reply.png' /> Reply</a></span><span class='metadata'><span class='author'><a href='http://twitter.com/{{screenName}}'><img src='{{profilePic}}' /></a><strong><a href='http://twitter.com/{{screenName}}'>{{realName}}</a></strong><br/>{{screenName}}</span></span></p></div>
NYAN

EM.run do
  SCHEDULER = Rufus::Scheduler::EmScheduler.start_new

  def deliver_tweet(user, tweet)
    template_data = {
      :id => tweet.id_str,
      :tweetURL => "http://www.twitter.com/#{tweet.user.screen_name}/statuses/#{tweet.id_str}",
      :screenName => tweet.user.screen_name,
        :realName => tweet.user.name,
        :tweetText => auto_link(tweet.text),
        :source => tweet.source,
        :profilePic => tweet.user.profile_image_url,
        :profileBackgroundColor => tweet.user.profile_background_color,
        :profileBackgroundImage => tweet.user.profile_use_background_image ? 'url(' + tweet.user.profile_background_image_url + ')' : 'none',
        :profileTextColor => tweet.user.profile_text_color,
        :profileLinkColor => tweet.user.profile_link_color,
        :timeStamp => tweet.created_at,
        :utcOffset => tweet.user.utc_offset
    }
    Juggernaut.publish("/tweets/#{user.token}", Mustache.render(TWEET_TEMPLATE, template_data))
  end

  def setup_jobs(user_id)
    user = User.new(user_id)
    if user.token.exists?
      puts "Setting up jobs for #{user.name}."
      t = Time.now
      user.schedule_calls(SCHEDULER) { |user, tweet|
        puts "[#{user.screen_name}]: #{tweet.user.screen_name}: #{tweet.text}"
        deliver_tweet(user, tweet)
      }
      puts "... done setting up jobs for #{user.name} (#{Time.now - t} secs)"
    end
  end

  def refresh(user_id)
    user = User.new(user_id)
    if user.token.exists?
      user.recent_tweets do |user,tweet|
        deliver_tweet(user,tweet)
      end
    end
  end

  User.all.each { |id|
    setup_jobs(id)
  }

  Thread.new { # have to run Redis subscription in a thread otherwise it blocks EventMachine
    redis = Redis::Namespace.new(:or, :redis => Redis.connect)
    redis.subscribe("usercommands") do |on|
      on.message do |type, data|
        data = JSON.parse(data)
        case data['command']
        when 'setup'
          setup_jobs(data['id'])
        when 'refresh'
          refresh(data['id'])
        end
      end
    end
  }
end
