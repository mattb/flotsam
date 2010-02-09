require 'rubygems'
require 'open-uri'
require 'yaml'

puts "graph berlin {"
for line in $stdin.readlines
    sleep 1
    line.match(/github.com\/(.*)/)
    me = $1
    if me.match(/^(.*)\/$/)
        me = $1
    end
    url = "http://github.com/api/v2/yaml/user/show/#{me}/followers"
    begin
        for link in YAML.load(open(url))["users"]
            puts "\"#{me}\" -> \"#{link}\";"
            $stdout.flush
        end
    rescue OpenURI::HTTPError
        puts "Error #{url}"
    end
end
puts "}"
