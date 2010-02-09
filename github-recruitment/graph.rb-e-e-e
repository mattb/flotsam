require 'rubygems'
require 'open-uri'
require 'yaml'

graph = {}
for line in $stdin.readlines
    sleep 1
    line.match(/github.com\/(.*)/)
    me = $1
    if me.match(/^(.*)\/$/)
        me = $1
    end
    url = "http://github.com/api/v2/yaml/user/show/#{me}/followers"
    begin
        graph[me] = []
        for link in YAML.load(open(url))["users"]
            graph[me] << link
        end
    rescue OpenURI::HTTPError,Timeout::Error
        puts "Error #{url}"
    end
end
result = Java::Ranker.new.rank(graph)
for user in result.sort_by { |user,score| score }
    puts "#{user[0]} = #{user[1]}"
end
