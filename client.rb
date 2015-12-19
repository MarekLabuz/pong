# require 'socket'      # Sockets are in standard library

# hostname = 'localhost'
# port = 5000

# socket = TCPSocket.open(hostname, port);

# while true
# 	line = gets  
# 	puts line.chop 
# end

# while line = socket.gets   # Read lines from the socket
#   puts line.chop      # And print with platform line terminator
# end


# socket.close  






require 'socket'
require 'gosu'




class PlayerPad
	attr_accessor :x, :y, :width, :height, :xSpeed	
	def initialize(y)
		@width = 200
		@height = 35
		@x = 1280/2 - @width/2 
		@y = y
		@xSpeed = 0
	end

	def set_speed(side)
		case side
			when "left"
				@xSpeed = -10;
			when "right"
				@xSpeed = 10
			else 
				@xSpeed = 0
		end
	end

	def move
		@x += @xSpeed
	end
	
	def draw
		Gosu::draw_rect(@x, @y, @width, @height, Gosu::Color.argb(0xff_ffffff), z = 0, mode = :default)
	end
end

#----------------------------------------Ball------------------------------------
class Ball
	attr_accessor :x, :y, :size, :xSpeed, :ySpeed

	def initialize
		@size = 25
		@x = 1280/2 - @size/2 
		@y = 720/2 - @size/2
		@xSpeed = 5
		@ySpeed = 5
	end
	
	def move
		@x += @xSpeed
		@y += @ySpeed
		
	end
	
	def change_side(side)
		case side
			when "vertical"
				@xSpeed *= -1
			when "horizontal"
				@ySpeed *= -1
		end
	end
	
	def wall_collision
		if (@x + @size >= 1280) || (@x <= 0)
			change_side("vertical")
		elsif (@y + @size >= 720) || (@y <= 0)
			change_side("horizontal")
		end
	end
	
	def draw
		Gosu::draw_rect(@x, @y, @size, @size, Gosu::Color.argb(0xff_ffffff), z = 0, mode = :default)
	end
end

#-------------------------------------GameWindow---------------------------------
class GameWindow < Gosu::Window
	def initialize(p1X, p2X)
		super 1280, 720
		self.caption = "Arkanoid"
    	@player1 = PlayerPad.new(p1X)
    	@player2 = PlayerPad.new(p2X)
    	@ball = Ball.new
    	


  #   	Thread.new { 
		# 	while line = @socket.gets
		# 		puts line
		# 		# split = (line.split(":"));
		# 		# @player2.x = split[2].to_i;
		# 		# @ball.x = split[4].to_i;
		# 		# @ball.y = split[5].to_i
		# 	end 
		# }
	end

	def button_down(id)
		case id
			when Gosu::KbLeft
				@player1.set_speed("left")
			when Gosu::KbRight
				@player1.set_speed("right")
			when Gosu::KbEscape, Gosu::KbQ
				close
		end 
	end
	
	def button_up(id)
		case id
			when Gosu::KbLeft, Gosu::KbRight
				@player1.set_speed("none")
		end 
	end

	def update
		@player1.move()
		# @ball.wall_collision()
		# @ball.move()
		# @socket.send(@player1.x.to_s, 0)
	end

	def draw
		@player1.draw()
		@player2.draw()
		@ball.draw()
	end
end







threads = []


hostname = 'localhost'
port = 5000
socket = TCPSocket.open(hostname, port);

puts "Available rooms:"
rooms = socket.gets.split(";")
rooms.each do |room|
	puts room
end

puts "What is your name?"
name = gets
socket.send(name, 0)
    
puts "What room do you want to join?"
name = gets
socket.send(name, 0)

line = gets.chomp;
if line == "1"
	window = GameWindow.new(720 - 1.5 * 35, 70 - 1.5 * 35)
else
	window = GameWindow.new(70 - 1.5 * 35, 720 - 1.5 * 35)
end


threads << Thread.new { 
	window.show
}

# threads << Thread.new { 
# 	while line = window.socket.gets
# 		# window.player2.x = line.to_i
# 		puts line.chop
# 	end 
# }


threads.each { |thr| thr.join }





















# while true
#   Thread.new(socketServer.accept) do |connection|
#     puts "Accepting connection from: #{connection.peeraddr[2]}"

#     begin
#       while connection
#         incomingData = connection.gets("\0")
#         if incomingData != nil
#           incomingData = incomingData.chomp
#         end

#         puts "Incoming: #{incomingData}"

#         if incomingData == "DISCONNECT\0"
#           puts "Received: DISCONNECT, closed connection"
#           connection.close
#           break
#         else
#           connection.puts "#{incomingData}"
#           connection.flush
#         end
#       end
#     rescue Exception => e
#       # Displays Error Message
#       puts "#{ e } (#{ e.class })"
#     ensure
#       connection.close
#       puts "ensure: Closing"
#     end
#   end
# end