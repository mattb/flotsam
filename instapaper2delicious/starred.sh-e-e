#!/bin/bash
# open a bunch of links tagged 'starred' in browser tabs so you can put real tags on them
for a in `ruby -rcgi -rrss -e "RSS::Parser.parse(open('http://feeds.delicious.com/v2/rss/mattb/starred')).items.each { |i| puts 'http://delicious.com/save?edit=yes&url=' + CGI.escape(i.link) }"` ; do open $a ; done
