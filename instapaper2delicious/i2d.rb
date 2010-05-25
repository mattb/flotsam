require 'rubygems'
require 'mechanize'

logon = 'http://www.instapaper.com/user/login'
username = 'mb@hackdiary.com'
password = 'biddulph'

a = Mechanize.new
a.get(logon) do |page|
    logged_on = page.form_with(:action => "/user/login") do |p|
        p.username = user
        p.password = pass
    end.submit
    debugger
end
