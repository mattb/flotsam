#!/usr/bin/env ruby
require 'rubygems'
require 'open-uri'
require 'stemmable'
require 'camping'
require 'mongrel'
require 'json'

class String
  include Stemmable
end

def find_dupes(username)
    tags = JSON.parse(open("http://del.icio.us/feeds/json/tags/#{username}?raw").read)
    equiv_classes = {}
    tags.keys.each { |tag|
        s = tag.stem
        if not equiv_classes.has_key? s
            equiv_classes[s] = [tag]
        else
            equiv_classes[s] << tag
        end
    }
    return tags.select { |tag,count|
        equiv_classes[tag.stem].size > 1
    }
end

Camping.goes :Stemtags

module Stemtags::Controllers
    class Page < R '/stemtags'
        def get()
            if @input.user
                @username = @input.user
                @dupes = find_dupes(@username)
                render :dupes
            else
                render :index
            end
        end
    end
end

module Stemtags::Views
    def layout
        html do
            head do
                title "del.icio.us tag stemmer"
                link :rel => 'stylesheet', 'type' => 'text/css', :href => 'http://www.hackdiary.com/style/hackdiary.css'
            end
            body do
                h1 do 
                    a :href=>'http://www.hackdiary.com/' do
                        img :width=>'147', :height=>'62', :class=>'title', :alt=>'hackdiary', :src=>'http://www.hackdiary.com/style/hackdiary.png'
                    end
                end
                div :id => 'widecontent' do
                    div :id => 'wideblog' do
                        h3 "del.icio.us tag stemmer"
                        p do 
                            text "This page uses <a href='http://www.tartarus.org/~martin/PorterStemmer/'>Porter stemming</a> to show where you've made different <a href='http://del.icio.us'>del.icio.us</a> tags with the same English word stem. You can use it to help clean up your personal <acronym title='thanks to Tom Coates for the best tagging-related neologism ever'>fauxonomy</acronym>"
                        end
                        form do 
                            text "Enter a del.icio.us username: <input type='text' name='user' /><input type='submit' /> (scans all URLs for that user)"
                        end
                        self << yield
                    end
                end
            end
        end
    end

    def index
    end

    def dupes
        h3 "Similar tags used by #{@username}"
        ul { 
            @dupes.sort_by { |d| [d[0].stem,0-d[1]] }.each { |tag,count|
                li {
                    a(:href => "http://del.icio.us/#{@username}/#{tag}") { tag } + " (#{count})"
                }
            }
        }
    end
end

if $0 == __FILE__ then
    config = Mongrel::Configurator.new :host => "0.0.0.0" do
        daemonize :cwd => Dir.pwd, :log_file => 'stemtags.log', :pid_file => 'stemtags.pid'
        listener :port => 3301 do
            uri "/", :handler => Mongrel::Camping::CampingHandler.new(Stemtags)
        end
        run
    end
    config.join
end
