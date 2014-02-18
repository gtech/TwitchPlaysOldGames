# Figure out how twitch chat integrates with IRC


# IRC bot scaffolding
# 2 second buffering code
# * voting system
# translate output of voting system to keyboard input into ZSNES
# UI on the right side, title, timer, previous move,current votes per button press, explicit log of button votes

#require_relative './display_time.rb'
#include DisplayTime
require 'win32ole'
require 'cinch'
require 'pry'
require 'observer'
require 'au3'

class Fixnum
  def year
    self * 365 * 24 * 60 * 60
  end
  def month
    self * 30 * 24 * 60 * 60
  end
  def week
    self * 7 * 24 * 60 * 60
  end
  def day
    self * 24 * 60 * 60
  end
  def hour
    self * 60 * 60
  end
  def minute
    self * 60
  end
  def second
    self 
  end
end

def pluralize(n, unit)
  if n > 1
    n.to_s + " " + unit.to_s + "s"
  else
    n.to_s + " " + unit.to_s
  end
end

def time_diff_in_natural_language(from_time, to_time)
  from_time = from_time.to_time if from_time.respond_to?(:to_time)
  to_time = to_time.to_time if to_time.respond_to?(:to_time)
  distance_in_seconds = ((to_time - from_time).abs).round
  components = []

  %w(year month week day hour minute second).each do |interval|
    # For each interval type, if the amount of time remaining is greater than
    # one unit, calculate how many units fit into the remaining time.
    if distance_in_seconds >= 1.send(interval)
      delta = (distance_in_seconds / 1.send(interval)).floor
      distance_in_seconds -= delta.send(interval)
      components << pluralize(delta, interval)
    end
  end

  components.join(", ")
end



class CommandSender
  def initialize
    @CODES = {up: "{UP}", down: "{DOWN}", left: "{LEFT}", right: "{RIGHT}", l: "l", r: "r", start: "{ENTER}", select: "{SPACE}", a: "a", b: "b", x: "x", y: "y"}
    @wsh = WIN32OLE.new('Wscript.Shell')
    @au3 = WIN32OLE.new "AutoItX3.Control"
    @au3.opt "WinTextMatchMode", 2
  end
  def send_command(key)
    key.to_sym
    @wsh.AppActivate "ZSNES"
    if key == :left or key == :right or key == :down or key == :up
      for i in 0..50
        @au3.Send @CODES[key]
      end
    else
      for i in 0..3
        @au3.Send @CODES[key]
      end
    end
  end
  def send_letter(l)
    @wsh.AppActivate "ZSNES"
    #sleep 0.1
    @au3.Send l
  end
end

class VoteCounter
  attr_reader :votes, :votes_hash
  def initialize
    @votes = 0
    @votes_hash = {up: 0, down: 0, left: 0, right: 0, l: 0, r: 0, start: 0, select: 0, a: 0, b: 0, x: 0, y: 0}
  end
  def vote(v)
    @votes_hash[v] = @votes_hash[v] + 1
    @votes += 1
  end
  def clear
    @votes = 0
    @votes_hash = {up: 0, down: 0, left: 0, right: 0, l: 0, r: 0, start: 0, select: 0, a: 0, b: 0, x: 0, y: 0}
  end    
  def verdict
    max = @votes_hash.values.max

    if max == 0
      return nil
    end

    winners = @votes_hash.select{|k, v| v == max}.keys
    len = winners.length
    if len > 1
      winners = winners[rand(len)]
    else
      winners = winners[0]
    end
    clear
    return winners
  end
end

class CommandHandler
  include Cinch::Plugin

#  match /^up$|^down$|^left$|^right$|^l$|^r$|^start$|^select$|^a$|^b$|^x$|^y$/, {use_prefix: false}
  match /^up$|^down$|^left$|^right$|^l$|^r$|^select$|^a$|^b$|^x$|^y$/, {use_prefix: false}

  def execute(m)
    @bot.message = m
    @bot.changed
    @bot.notify_observers
  end
end

class TwitchPlaysIRCBot < Cinch::Bot
  include Observable
  attr_accessor :message
  def initialize
    super
    @message = nil
    loggers.clear
    loggers << Cinch::Logger::FormattedLogger.new(File.open("C:/Users/gtech/Documents/GitHub/TwitchPlaysOldGames/Cinch.log", "a"))
    configure do |c|
      c.server = "irc.twitch.tv"
      c.channels = ["#twitchplaysoldgames"]
      c.nick = "twitchplaysgamesbot"
      c.password = "oauth:5b68839ththg7b5wybqtcaenfssdrwc"
      c.plugins.plugins = [CommandHandler]
    end
  end
end

class OverSeer
  def initialize
    @irc_bot = TwitchPlaysIRCBot.new
    @irc_bot.add_observer self, :voted
    @vc = VoteCounter.new
    @buffer = Array.new
    @cs = CommandSender.new
    @buffer_max = 40
    @polling_rate = 0.5
    @chat_votes = Array.new
    @max_chat_votes = 10
    @last_move = "None"
    @verticle_buffer = 19
    @INIT_TIME = Time.now
  end
  def render_votes()
    hash = @vc.votes_hash
    space = " "
    spacing = space*65

    chat_votes_para = String.new
    for i in 0..(@chat_votes.length - 1)
      chat_votes_para += spacing + "#{@chat_votes[i].user}: #{@chat_votes[i].message}\n"
    end
    system "clear" or system "cls"
    puts spacing + " " + time_diff_in_natural_language(@INIT_TIME, Time.now)
    puts spacing + "Up: #{hash[:up]}, Down: #{hash[:down]}, Right: #{hash[:right]}, Left: #{hash[:left]}
 #{spacing} L: #{hash[:l]},R: #{hash[:r]}, Start: #{hash[:start]}, Select: #{hash[:select]}
 #{spacing} A: #{hash[:a]}, B: #{hash[:b]}, X: #{hash[:x]}, Y: #{hash[:y]}"
    puts chat_votes_para
    puts spacing + "Last move was: #{@last_move}"
    puts spacing + "Buffer: #{@buffer.length}/#{@buffer_max}\n"
    puts spacing + "Upcoming Moves:\n"
    buffer_display_array = Array.new
    buffer_display = String.new
#    @buffer = [:up, :left, :right, :up, :up, :left, :right, :up,:up, :left, :right, :up,:up, :left, :right, :up,:up, :left, :right, :up,:up, :left, :right, :up,:up, :left, :right, :up,:up, :left, :right, :up,:up, :left, :right, :up,:up, :left, :right, :up]
    len = @buffer.length
    if len > @verticle_buffer
      for i in 0..@verticle_buffer
        buffer_display += spacing + (i+1).to_s + ": " + @buffer[i].to_s + "\n"
      end
      for i in (@verticle_buffer+1)..(len-1)
        buffer_display += (i+1).to_s + ": " + @buffer[i].to_s + "\n"
      end
    else
      for i in 0..(len - 1)
        buffer_display += spacing + (i+1).to_s + ": " + @buffer[i].to_s + "\n"
      end
    end    
    puts buffer_display
    #     Shoes.app do
    #       @vote_tallies = stack do
    #         para "Up: #{hash[:up]}, Down: #{hash[:down]}, Right: #{hash[:right]}, Left: #{hash[:left]}
    # L: #{hash[:l]},R: #{hash[:r]}, Start: #{hash[:start]}, Select: #{hash[:select]}
    # A: #{hash[:a]}, B: #{hash[:b]}, X: #{hash[:x]},Y: #{hash[:y]}"
    #       end
    #       @chat_votes_dislay = stack do
    #         para chat_votes_para
    #       end
    #     end
  end
  def render_moves
    #This is where we render our moves window TODO
  end
  def voted
    m = @irc_bot.message
    @vc.vote(m.message.to_sym)
    if @chat_votes.length == @max_chat_votes
      @chat_votes.delete_at 0
      @chat_votes.push m
    else
      @chat_votes.push m
    end
    render_votes
  end
  def main
    Thread.new do
      @irc_bot.start
    end
    while true
      sleep @polling_rate

      unless result = @vc.verdict
        next
      end

      @buffer.push result
#      if @buffer.length == @buffer_max
        @last_move = @buffer.delete_at(0)
        @cs.send_command @last_move
        render_votes
#      end
    end
  end
end
# When a vote comes in, it should be tallied
# There should be a loop running which counts the votes and adds to the buffer at the end of the counting time
# when the loop ends, buffer is checked if it's full, if it is then the first move is sent to the game.'

#TODO this means we need to know how to render separate windows
# I need three windows for the interface:
#   one which is static and shows what the game is, we can do that out of ruby.
#   one which shows the current votes for all moves, and people's names and which move they voted for
#   a final one which shows all the moves in the buffer, and how full the buffer is

#TODO
#I'd like to have the game dynamically change the buffer and polling rate base on how many people are playing.
#We can do this by calculating votes per second, at the end of every polling cycle
#How do we want to change these variables based on votes/second?

#TODO timer
os = OverSeer.new
os.main
