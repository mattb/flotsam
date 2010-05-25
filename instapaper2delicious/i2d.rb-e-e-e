require 'rubygems'
require 'mechanize'
require 'httparty'
require 'yaml'

class Delicious
  include HTTParty
  base_uri 'https://api.del.icio.us/v1'
  
  def initialize(auth)
    @auth = auth
  end

  def add(options)
      self.class.get("/posts/add", :query => options, :basic_auth => @auth)
  end
end

CONFIG = YAML.load(open("config.yml"))

logon = 'http://www.instapaper.com/user/login'
username = CONFIG['instapaper_username']
password = CONFIG['instapaper_password']

delicious = Delicious.new( :username => CONFIG['delicious_username'], :password => CONFIG['delicious_password'] )

a = Mechanize.new
a.get(logon) do |page|
    logged_on = page.form_with(:action => "/user/login") do |p|
        p.username = username
        p.password = password
    end.submit
    starred = a.get("http://www.instapaper.com/starred")
    starred.parser.xpath("//a[@class='tableViewCellTitleLink']").reverse.each { |link|
        puts link.text()
        delicious.add(:url => link.attr("href"), :description => link.text(), :tags => "starred", :replace => "no")
    }
end
