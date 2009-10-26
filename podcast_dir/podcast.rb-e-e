require 'rubygems'
require 'mp3info'
require 'cgi'
require 'rss/maker'

rss = RSS::Maker.make("2.0") do |rss|
    rss.channel.title = "TITLE"
    rss.channel.link = "http://www.example.com"
    rss.channel.description = "DESCRIPTION"
    rss.items.do_sort = true
    Dir.glob("*.mp3").each do |f|
        Mp3Info.open(f) do |mp3|
            i = rss.items.new_item
            i.title = "#{mp3.tag2.TALB}: #{mp3.tag2.TIT2}"
            if mp3.tag2.COMM.is_a? Array
                i.description = mp3.tag2.COMM.sort_by { |d| d.size }.last
            else
                i.description = mp3.tag2.COMM
            end
            stat = File::Stat.new(f)
            i.date = stat.mtime
            i.link = "http://www.hackdiary.com/bbc/#{CGI.escape(f)}"
            e = i.enclosure
            e.url = i.link
            e.length = stat.size
            e.type = "audio/mpeg"
        end
    end
end
puts rss
