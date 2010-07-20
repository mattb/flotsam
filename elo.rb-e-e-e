K=10

class Player
    attr_accessor :rating
    def initialize
        @rating = 1200
    end

    def expectancy_versus(player)
        diff = self.rating - player.rating
        return 1.0 / (1.0 + (10 ** (diff/400.0)))
    end

    def won_against(player)
        delta = (K * self.expectancy_versus(player)).to_i
        player.rating -= delta
        self.rating += delta
    end
end

# make the first 100 words in the dictionary play each other
# at a game of "who is the longest?"
# to help get a feel for how Elo distributes.
words = open("/usr/share/dict/words").readlines.slice(0,100).map { |line| line.downcase.chomp }
players = {}
words.each { |word|
    players[word] = Player.new
}

100000.times do
    p1 = words[rand*words.size]
    p2 = words[rand*words.size]
    if p1 != p2
        #puts "#{p1} played #{p2}"
        if p1.size > p2.size
            players[p1].won_against(players[p2])
        else
            players[p2].won_against(players[p1])
        end
    end
end
players.sort_by { |word, player| player.rating }.reverse.slice(0,100).each { |word, player|
    puts "#{word}: #{player.rating}"
}
