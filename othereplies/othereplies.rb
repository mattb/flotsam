require 'rubygems'
$KCODE='UTF8'
require 'bundler/setup'
Bundler.require
include Twitter::Autolink

SEEN = {}

require 'twitter-config'
# twitter-config.rb should contain something like: 
# Twitter.configure do |config|
#   config.consumer_key = "BG..."
#   config.consumer_secret = "Oj..."
#   config.oauth_token = "12530-..."
#   config.oauth_token_secret = "oe..."
# end
#
# you can use twitter_auth to generate the tokens:

def twitter_auth
  consumer = OAuth::Consumer.new Twitter.options[:consumer_key],
    Twitter.options[:consumer_secret],
    { :site => 'http://twitter.com/',
      :request_token_path => '/oauth/request_token',
      :access_token_path => '/oauth/access_token',
      :authorize_path => '/oauth/authorize'}

  request_token = consumer.get_request_token
  system("open", request_token.authorize_url)
  print "Enter the number they give you: "
  pin = STDIN.readline.chomp

  access_token = request_token.get_access_token(:oauth_verifier => pin)

  puts access_token.get('/account/verify_credentials.json')
  return access_token
end

rates = Twitter.rate_limit_status
ids = Twitter.friend_ids.ids.sort_by { rand }

frequency = (ids.size.to_f / (rates.hourly_limit - 25)).ceil # how many hours we should take to cycle through all the IDs without busting the rate limit.

scheduler = Rufus::Scheduler.start_new

tweetTemplate = "<!-- {{{tweetURL}}} --> ";
tweetTemplate += "<style type='text/css'>.bbpBox{{id}} {background-image:{{{profileBackgroundImage}}}; background-color: \#{{{profileBackgroundColor}}};padding:20px;} p.bbpTweet{background:#fff;padding:10px 12px 10px 12px;margin:0;min-height:48px;color:#000;font-size:18px !important;line-height:22px;-moz-border-radius:5px;-webkit-border-radius:5px} p.bbpTweet span.metadata{display:block;width:100%;clear:both;margin-top:8px;padding-top:12px;height:40px;border-top:1px solid #fff;border-top:1px solid #e6e6e6} p.bbpTweet span.metadata span.author{line-height:19px} p.bbpTweet span.metadata span.author img{float:left;margin:0 7px 0 0px;width:38px;height:38px} p.bbpTweet a:hover{text-decoration:underline}p.bbpTweet span.timestamp{font-size:12px;display:block}</style> ";
tweetTemplate += "<div class='bbpBox{{id}}'><p class='bbpTweet'>{{{tweetText}}}<span class='timestamp'><a title='{{timeStamp}}' href='{{{tweetURL}}}'>less than a minute ago</a> via {{{source}}} <a href='http://twitter.com/intent/favorite?tweet_id={{id}}'><img src='http://si0.twimg.com/images/dev/cms/intents/icons/favorite.png' /> Favorite</a> <a href='http://twitter.com/intent/retweet?tweet_id={{id}}'><img src='http://si0.twimg.com/images/dev/cms/intents/icons/retweet.png' /> Retweet</a> <a href='http://twitter.com/intent/tweet?in_reply_to={{id}}'><img src='http://si0.twimg.com/images/dev/cms/intents/icons/reply.png' /> Reply</a></span><span class='metadata'><span class='author'><a href='http://twitter.com/{{screenName}}'><img src='{{profilePic}}' /></a><strong><a href='http://twitter.com/{{screenName}}'>{{realName}}</a></strong><br/>{{screenName}}</span></span></p></div>";

# space the checks out over the next #{frequency} hours
ids.each_with_index do |id, idx|
  scheduler.every frequency.to_s + "h", :first_in => ((frequency*60.0*60.0/ids.size)*idx).to_i.to_s + "s" do
    Twitter.user_timeline(id).select { |tweet|
      wanted = (!tweet.in_reply_to_user_id.nil? and !SEEN.include?(tweet.id) and !ids.include?(tweet.in_reply_to_user_id))
      SEEN[tweet.id] = 1
      wanted
    }.each { |tweet|
      puts "#{tweet.user.screen_name}: #{tweet.text}"
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
      Juggernaut.publish("/tweets", Mustache.render(tweetTemplate, template_data))
    }
  end
end

# serve up the static index.html for the Juggernaut code to use
my_app = Sinatra.new { 
  set :public, "public"
}
my_app.run!
