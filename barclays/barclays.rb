# screenscrape account balances from Barclays online banking
require 'rubygems'
require 'mechanize'

SURNAME="SURNAME"
DOB = ["DD","MM","YYYY"]
CARD = ["1234","5678","9012","3456"]
SECURITY_CODE = "123"

a = WWW::Mechanize.new { |agent|
    agent.user_agent_alias = 'Mac Mozilla'
}
page = a.get('https://ibank.barclays.co.uk/olb/o/MobiBasicAccessStart.do')
result = page.form_with(:action => 'MobiBasicAccess.do') do |login|
    login.surname = SURNAME
    login.dobDay = DOB[0]
    login.dobMonth = DOB[1]
    login.dobYear = DOB[2]
    login.connectCard1 = CARD[0]
    login.connectCard2 = CARD[1]
    login.connectCard3 = CARD[2]
    login.connectCard4 = CARD[3]
    login.securityCode = SECURITY_CODE
end.click_button
accounts = result.search("//table[@id='AccountDetails']/tr[@class='allowrowspan']")
accounts.each { |account|
    name = account.search("td[@class='bodytext8']//text()").map { |x| x.to_s.strip }.join(" ").strip
    amount = account.search("td/b/text()").to_s.gsub(/[^0-9.]/,"").to_f
    puts "#{name}: #{amount}"
}
