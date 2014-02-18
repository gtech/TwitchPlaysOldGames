require 'Cinch'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.twitch.tv"
    c.channels = ["#twitchplaysoldgames"]
    c.nick = "gtechiii"
    c.password = "oauth:5b68839ththg7b5wybqtcaenfssdrwc"
  end
end

Tread.new {
  bot.start
}
while true
