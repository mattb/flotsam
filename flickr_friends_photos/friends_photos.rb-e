# create an atom feed of non-public photos from friends. run it once an hour and it'll track state in a sqlite3 db.
require 'rubygems'
require 'flickraw' # gem
require 'time'
require 'rss'
require 'datamapper' # gem

DataMapper.setup(:default, 'sqlite3:///tmp/friends_photos.sqlite3')

class Photo
    include DataMapper::Resource
    property :id,        Integer, :serial => true
    property :datetaken, Time
    property :url,       String, :size => 255
    property :flickrid,  String
    property :owner,     String
    property :ownername, String
    property :title,     String
end

# NOTE: uncomment this for first run to create database
# Photo.auto_migrate! 

FlickRaw.shared_secret='YOUR SECRET HERE'
FlickRaw.api_key='YOUR API KEY HERE'

# NOTE: token setup
frob = flickr.auth.getFrob
auth_url = FlickRaw.auth_url :frob => frob, :perms => 'read'
puts "Open this url in your process to complete the authication process : #{auth_url}"
puts "Press Enter when you are finished."
STDIN.getc
token = flickr.auth.getToken :frob => frob

token = 'YOUR TOKEN HERE' # NOTE: stashed from a previous run of the above

photos = flickr.photos.getContactsPhotos(:auth_token => token, :just_friends => 1, :extras => 'date_taken,owner_name',:count=>50)
flickr.contacts.getListRecentlyUploaded(:auth_token => token).each { |content|
    photos += flickr.photos.search(:user_id => content.nsid, :extras => 'date_taken,owner_name', :auth_token => token)
}
photos.select { |p| p.ispublic == 0 }.each do |photo|
    p = Photo.first(:flickrid => photo.id)
    if p.nil?
        p = Photo.new
    end
    url = "http://farm#{photo.farm}.static.flickr.com/#{photo.server}/#{photo.id}_#{photo.secret}_m.jpg"
    p.attributes = {
        :datetaken => Time.parse(photo.datetaken),
        :url => url,
        :flickrid => photo.id,
        :owner => photo.owner,
        :ownername => photo.ownername,
        :title => photo.title
    }
    p.save
end

photos = Photo.all

atom = RSS::Maker.make("atom") do |maker|
    maker.channel.about = "http://example.com"
    maker.channel.title = "Friends-only photos"
    maker.channel.description = ""
    maker.channel.link = "http://www.hackdiary.com"

    maker.channel.date = Time.now
    maker.channel.author = "mattb"

    maker.items.do_sort = true

    photos.each do |photo|
        maker.items.new_item do |item|
            item.link = "http://www.flickr.com/photos/#{photo.owner}/#{photo.id}"
            item.title = photo.title
            item.content.type = "xhtml"
            item.content.xhtml = "<img src='#{photo.url}' /><br />from #{photo.ownername}"
            item.date = photo.datetaken
        end
    end 
end

puts atom.to_s
