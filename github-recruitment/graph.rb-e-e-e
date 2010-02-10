require 'rubygems'
require 'net/http'
require 'yaml'
require 'cgi'
require 'bossman'
include BOSSMan

$stdout.sync = true
puts "Getting URLs"
BOSSMan.application_id = YAML.load_file("config.yml")['yahookey']
offset = 0
done = false
urls = []
while !done
    results = BOSSMan::Search.web('site:github.com location "' + ARGV[0] + '" "profile - github"', :start => offset)
    offset += results.count.to_i
    if offset > results.totalhits.to_i
        done = true
    end
    urls += results.results.map { |r| r.url }
end

puts "Getting social graph"
graph = {}
Net::HTTP.start('github.com') { |http|
    for line in urls
        sleep 1
        line.match(/github.com\/([a-zA-Z0-9-]+)/)
        me = $1
        if me.match(/^(.*)\/$/)
            me = $1
        end
        url = "/api/v2/yaml/user/show/#{me}/followers"
        puts url
        req = Net::HTTP::Get.new(url)
        response = http.request(req)
        case response 
        when Net::HTTPSuccess
            graph[me] = []
            for link in YAML.load(response.body)["users"]
                graph[me] << link
            end
        else
            puts "non-200: #{me}"
        end
    end
}
result = Java::Ranker.new.rank(graph)
for user in result.sort_by { |user,score| score }
    puts "#{user[0]} = #{user[1]}"
end
