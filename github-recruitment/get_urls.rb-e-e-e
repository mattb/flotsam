require 'rubygems'
require 'cgi'

require 'bossman'
include BOSSMan

BOSSMan.application_id = "JTQbH2jV34Gd2SsnIebEjz2cZVM2CmJ1wEwB3qdQusJ3OQy.ArjXwMbaVCBWvsYsWzaBANNu"
offset = 0
done = false
while !done
    results = BOSSMan::Search.web('site:github.com location berlin "profile - github"', :start => offset)
    offset += results.count.to_i
    if offset > results.totalhits.to_i
        done = true
    end
    puts results.results.map { |r| r.url }.join("\n")
    $stdout.flush
end
