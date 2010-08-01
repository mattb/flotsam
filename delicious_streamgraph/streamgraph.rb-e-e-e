require 'rubygems'
require 'clusterer'
require 'stemmer'
require 'nokogiri'


class Deliciousdata
    attr_accessor :xml

    def initialize
        @xml = Nokogiri::XML.parse(open('all.xml'))
    end

    # curl 'https://username:password@api.del.icio.us/v1/posts/all' > all.xml
    def tags
        return self.posts.map { |p| p['tag'].join(" ") }
    end

    def posts
        self.xml.xpath("//post").map { |p|
            h = {}
            p.attributes.each { |k,v|
                if k == 'time'
                    h[k] = Time.parse(v.to_s)
                elsif k == 'tag'
                    h[k] = v.to_s.split(/ /)
                else
                    h[k] = v.to_s
                end
            }
            h
        }.sort_by { |p|
            p['time']
        }
    end

    def clusters
        @c ||= Clusterer::Clustering.cluster(:kmeans, self.tags, :no_stem => false, :tokenizer => :simple_tokenizer, :no_of_clusters => 15)
    end

    def chartdata
        factor = 60 * 60 * 24 * 7 * 4 # 4 week clumps
        post_groups = self.posts.group_by { |p| Time.at(factor * (p['time'].to_i / factor).to_i) }
        return post_groups.sort_by { |timestamp, ps| timestamp }.map { |timestamp, ps|
            [timestamp, self.popularity(ps)]
        }
    end

    def popularity(ps=nil)
        ps ||= self.posts
        groups = self.clusters.map { |c| c.centroid.to_a.sort_by { |term,score| -score }.map { |term, score| term } }
        scores = {}
        groups.each { |group|
            title = group.slice(0,6).join("-")
            scores[title] = 0
        }
        ps.each { |post|
            groups.each { |group|
                if post['tag'].any? { |tag| group.include?(tag.stem) }
                    title = group.slice(0,6).join("-")
                    scores[title] += 1
                end
            }
        }
        return scores
    end
end
