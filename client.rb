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


WIDTH = 400
HEIGHT = 800

class PlayerPad
	attr_accessor :x, :y, :width, :height, :xSpeed	
	def initialize(x)
		@width = 35
		@height = 200
		@x = x
		@y = HEIGHT/2 - @height/2 
		@ySpeed = 0
	end

	def set_speed(side)
		case side
			when "up"
				@ySpeed = -10;
			when "down"
				@ySpeed = 10
			else 
				@ySpeed = 0
		end
	end

	def move
		@y += @ySpeed
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
		@x = WIDTH/2 - @size/2 
		@y = HEIGHT/2 - @size/2
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
	def initialize(p1X, p2X, socket)
		super WIDTH, HEIGHT
		self.caption = "Arkanoid"
    	@player1 = PlayerPad.new(p1X)
    	@player2 = PlayerPad.new(p2X)
    	@ball = Ball.new
    	@socket = socket
    	

    	Thread.new { 
			while line = @socket.gets
				puts line
				split = line.split("\n");
				@player2.y = split[0].to_i;
				# @ball.x = split[4].to_i;
				# @ball.y = split[5].to_i
			end 
		}
	end

	def button_down(id)
		case id
			when Gosu::KbUp
				@player1.set_speed("up")
			when Gosu::KbDown
				@player1.set_speed("down")
			when Gosu::KbEscape, Gosu::KbQ
				close
		end 
	end
	
	def button_up(id)
		case id
			when Gosu::KbUp, Gosu::KbDown
				@player1.set_speed("none")
		end 
	end

	def update
		@player1.move()
		# @ball.wall_collision()
		# @ball.move()
		@socket.send(@player1.y.to_s, 0)
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

line = socket.gets;
if line == "1\n"
	window = GameWindow.new(10, WIDTH - 35 - 10, socket)
else
	window = GameWindow.new(WIDTH - 35 - 10, 10, socket)
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