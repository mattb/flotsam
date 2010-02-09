#
# ajax_search.rb v0.2 by Postmodern (postmodern at sophsec.com)
#
# Usage:
#
#   SophSec.ajax_search(:q => 'Ruby', :rsz => 'small')
#
#   SophSec.ajax_search(:q => 'Ruby', :lstkp => 16)
#
#   SophSec.ajax_search(:q => 'inurl:ruby', :lstkp => 16)
#

require 'uri'
require 'net/http'
require 'json'

module SophSec
  def SophSec.get_ajax_search(options={})
    options[:callback] ||= 'google.search.WebSearch.RawCompletion'
    options[:context] ||= 0
    options[:lstkp] ||= 0
    options[:rsz] ||= 'large'
    options[:hl] ||= 'en'
    options[:gss] ||= '.com'
    options[:start] ||= 0
    options[:sig] ||= '582c1116317355adf613a6a843f19ece'
    options[:key] ||= 'notsupplied'
    options[:v] ||= '1.0'

    url = URI("http://www.google.com/uds/GwebSearch?" + options.map { |key,value|
      "#{key}=#{value}"
    }.join('&'))

    return Net::HTTP.get(url)
  end

  def SophSec.ajax_search(options={})
    hash = JSON.parse(SophSec.get_ajax_search(options).scan(/\{.*\}/).first)

    if (hash.kind_of?(Hash) && hash['results'])
      return hash['results']
    end

    return []
  end
end
