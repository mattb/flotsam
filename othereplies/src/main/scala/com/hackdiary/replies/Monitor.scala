package com.hackdiary.replies

import scala.collection.JavaConversions._

import java.util.concurrent.TimeUnit._

import com.ning.http.client._
import org.codehaus.jackson.map._
import org.codehaus.jackson._

import com.yammer.metrics.Instrumented
import java.util.concurrent.TimeUnit
import com.yammer.metrics.reporting.ConsoleReporter

import redis.clients.jedis._

import akka.actor._
import akka.routing._
import akka.config._
import akka.config.Supervision._

case class Poll() 
case class Start() 
case class InterestedInUsers(users : List[String])
case class Response(params : Map[String,String], response : com.ning.http.client.Response) 
case class Tweet(tweet : JsonNode) 

object Monitor extends App {
  val jedispool = new JedisPool(new JedisPoolConfig(), "localhost")

  val monitor = Actor.actorOf[Monitor].start

  val factory = SupervisorFactory(
    SupervisorConfig(
      OneForOneStrategy(List(classOf[Exception]), 3, 10),
      Supervise(monitor, Permanent) ::
      Nil)
    )

  factory.newInstance.start
  monitor ! Start
  //ConsoleReporter.enable(10, TimeUnit.SECONDS)
}

class Monitor extends Actor {
  def receive = {
    case Start => {
      for((token,n) <- User.unwrapped_redis(_.smembers("or:users")) zipWithIndex) {
        val actor = Actor.actorOf(User(self, token)).start
        self.link(actor)
        Scheduler.schedule(actor, Poll, n % 12, 12, SECONDS)
      }
      become(ready(Map.empty))
    }
  }
  def ready(registry : Map[String, Set[UntypedChannel]]) : Receive = {
    case InterestedInUsers(users) => {
      val newRegistry = registry ++ users.map(id => { (id -> (registry.getOrElse(id, Set.empty) + self.channel)) })
      become(ready(newRegistry))
    }
    case Tweet(tweet) => {
      if(!(tweet path "in_reply_to_user_id" isNull)) {
        val user_id = tweet.path("user").path("id_str").getTextValue
        for(user <- registry.getOrElse(user_id, Set.empty)) user ! Tweet(tweet)
      }
    }
  }
}
