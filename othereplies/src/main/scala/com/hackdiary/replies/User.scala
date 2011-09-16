package com.hackdiary.replies

import java.lang.reflect.{Method,InvocationHandler,Proxy}

import com.ning.http.client._
import com.ning.http.client.oauth._
import org.codehaus.jackson._
import org.codehaus.jackson.map._
import com.codahale.jerkson.Json._
import java.util.concurrent.{ExecutionException, Executor}

import com.yammer.metrics.Instrumented
import java.util.concurrent.TimeUnit
import com.yammer.metrics.reporting.ConsoleReporter

import redis.clients.jedis._

import akka.actor._
import akka.event._

import Actor._

import collection.JavaConversions._
import org.scala_tools.time.Imports._

object User extends Instrumented {
  private val redisTimer = metrics.timer("redis")
  val asyncHttpClient = new AsyncHttpClient
  
  def unwrapped_redis[T](f: Jedis => T) = {
    redisTimer.time {
      val jedis = Monitor.jedispool.getResource
      try {
        f(jedis)
      } finally {
        Monitor.jedispool.returnResource(jedis)
      }
    }
  }

  def redis[T](token : String, f: JedisCommands => T) = {
    redisTimer.time {
      val jedis = Monitor.jedispool.getResource
      val handler = new InvocationHandler() {
        def invoke(proxy: AnyRef, method: Method, args: Array[AnyRef]): AnyRef = {
          args(0) = redisKey(token, args(0).asInstanceOf[String])
          method.invoke(jedis, args:_*)
        }
      }
      
      val wrapper = Proxy.newProxyInstance(jedis.getClass.getClassLoader,
        Array(classOf[JedisCommands]), handler).asInstanceOf[JedisCommands]

      try f(wrapper)
      finally Monitor.jedispool.returnResource(jedis)
    }
  }

  def redisKey(token : String, key : String) = {
    "or:user:" + token + ":" + key
  }
}

class User(monitor : ActorRef, token : String) extends Actor with Instrumented {
  def redis[T](f: JedisCommands => T) = User.redis(token, f)

  val screen_name = redis(_.get("screen_name"))
  val secret = redis(_.get("secret"))
  val calculator = new OAuthSignatureCalculator(new ConsumerKey(TwitterConfig.consumer_key,
    TwitterConfig.consumer_secret), new RequestToken(token, secret))
  val following : List[String] = redis(_.lrange("following",0,-1)) toList

  val deliverTimer = metrics.timer("deliver")
  val jsonTimer = metrics.timer("json")

  val mapper = new ObjectMapper
  val time = DateTimeFormat.forPattern("EEE MMM dd HH:mm:ss Z yyyy")

  override def preStart = {
    monitor ! InterestedInUsers(following)
  }

  def receive = {
    case Poll => poll
    case Tweet(tweet) => deliverTweet(tweet)
    case Response(params, response) => handleResponse(params, response)
  }

  def poll = if(following.size > 0) httpasync("http://api.twitter.com/1/statuses/user_timeline.json",nextParams)
    
  def handleResponse(params : Map[String,String], response : com.ning.http.client.Response) {
    response.getStatusCode match {
      case 200 => {
        val json = response.getResponseBody
        val max_ids = jsonTimer.time {
          mapper.readTree(json).map(tweet => {
            monitor ! Tweet(tweet)
            tweet path "id" getLongValue
          })
          }
        if(max_ids nonEmpty) {
          redis(_.hset("since_ids",params("user_id"),max_ids.max toString))
        }
        }
      case 400 => EventHandler.error(this,"Bad request:" + response.getResponseBody)
      case 401 => EventHandler.error(this,"Unauthorized!")
      case m => EventHandler.error(this,"Other problem!")
    }
  }

  def wanted(t : JsonNode) = redis(! _.sismember("seen", t path "id_str" getTextValue)) && !(following contains(t path "in_reply_to_user_id_str" getTextValue))
  
  def deliverTweet(t : JsonNode) : Unit = {
    if(wanted(t)) {
      deliverTimer.time {
        val templateData = Map(
          "id" -> (t path "id_str" getTextValue),
          "tweetURL" -> "http://www.twitter.com/%s/statuses/%s".format(t path "user" path "screen_name" getTextValue,t path "id_str" getTextValue),
          "screenName" -> (t path "user" path "screen_name" getTextValue),
          "realName" -> (t path "user" path "name" getTextValue),
          "tweetText" -> (t path "text" getTextValue),
          "source" -> (t path "source" getTextValue),
          "inReplyTo" -> (t path "in_reply_to_status_id_str" getTextValue),
          "profilePic" -> (t path "user" path "profile_image_url" getTextValue),
          "profileBackgroundColor" -> (t path "user" path "profile_background_color" getTextValue),
          "profileBackgroundImage" -> "url(%s)".format(t path "user" path "profile_background_image_url" getTextValue),
          "profileTextColor" -> (t path "user" path "profile_text_color" getTextValue),
          "profileLinkColor" -> (t path "user" path "profile_link_color" getTextValue),
          "timeStamp" -> (t path "created_at" getTextValue),
          "timeStamp_i" -> (time.parseDateTime(t path "created_at" getTextValue).millis / 1000),
          "utcOffset" -> (t path "user" path "utc_offset" getIntValue)
        )
        val json = generate(templateData)
        EventHandler.info(this,"From @%s for @%s: %s".format(templateData("screenName"),screen_name,templateData("tweetText")))
        redis(r => {
          r.zadd("timeline", (time.parseDateTime(t path "created_at" getTextValue).millis / 1000), json)
          r.zremrangeByRank("timeline", 0, -50)
        })
        User.unwrapped_redis(_.publish("juggernaut", generate(Map("channels" -> List("/tweets/" + token), "data" -> json))))
      }
    }
    redis(_.sadd("seen", t path "id_str" getTextValue))
  }

  def httpasync(url : String, params : Map[String,String]) = {
    val builder = User.asyncHttpClient.prepareGet(url).setSignatureCalculator(calculator)
    for((k,v) <- params) builder.addQueryParameter(k,v)
    val ahcFuture = User.asyncHttpClient.executeRequest(builder.build)
    ahcFuture.addListener(new Runnable { def run = self ! Response(params, ahcFuture.get) }, 
                          new Executor { def execute(r : Runnable) = r.run })
  }

  def nextParams = {
    redis(r => {
      val u = r.lpop("following")
      r.rpush("following",u)
      val params = Map("user_id" -> u)
      if(r.hexists("since_ids",u)) {
        params + ("since_id" -> r.hget("since_ids",u))
      } else {
        params
      }
    })
  }
}
