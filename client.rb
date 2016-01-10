require 'socket'
require 'gosu'

WIDTH = 600
HEIGHT = 700

class PlayerPad
	attr_accessor :x, :y, :width, :height, :ySpeed, :auto
	def initialize(x)
		@width = 35
		@height = 200
		@x = x
		@y = HEIGHT/2 - @height/2 
		@ySpeed = 0
		@auto = false
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
		if (@y > 0 && @ySpeed < 0) || (@y + @height < HEIGHT && @ySpeed > 0) 
			@y += @ySpeed
		end
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
		self.caption = "Pong"
    	@player1 = PlayerPad.new(p1X)
    	@player2 = PlayerPad.new(p2X)
    	@ball = Ball.new
    	@socket = socket
    	@font = Gosu::Font.new(40)
    	@player1score = 0
    	@player2score = 0
    	

    	Thread.new { 
			while line = @socket.gets
				# puts line
				# "position;500\n" -> ["position;500"] -> ["position","500"]
				message = line.split("\n");
				message2 = message[0].split(";");
				if message2[0] == "position"
					@player2.y = message2[1].to_i;
				elsif message2[0] == "score"
					@player1score = message2[1].to_i
    				@player2score = message2[2].to_i
				else
					@ball.x = message2[1].to_i;
					@ball.y = message2[2].to_i;
				end
				
				# @ball.x = split[4].to_i;
				# @ball.y = split[5].to_i
			end 
		}
	end

	def button_down(id)
		case id
			when Gosu::KbUp
				@player1.set_speed("up")
				@player1.auto = false
			when Gosu::KbDown
				@player1.set_speed("down")
				@player1.auto = false
			when Gosu::KbEscape, Gosu::KbQ
				close
			when Gosu::KbA
				@player1.auto = !@player1.auto
		end 
	end
	
	def button_up(id)
		case id
			when Gosu::KbUp, Gosu::KbDown
				@player1.set_speed("none")
		end 
	end

	def update
		if @player1.auto == true 
			if (@player1.y  + @player1.height/2 - @ball.y).abs > 10
				if @ball.y > @player1.y + @player1.height/2
					@player1.set_speed("down")
				else
					@player1.set_speed("up")
				end
			else
				@player1.set_speed("none")
			end
		end
		@player1.move()
		# @ball.wall_collision()
		# @ball.move()
		@socket.send(@player1.y.to_s, 0)
	end

	def draw
		@player1.draw()
		@player2.draw()
		@ball.draw()
		@font.draw("#{@player1score}:#{@player2score}", WIDTH/2 - 20, 20, 1, 1.0, 1.0, 0xff_ffffff)
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
room = gets
socket.send(room, 0)

line = socket.gets;
if line == "1\n"
	window = GameWindow.new(WIDTH - 35 - 10, 10, socket)
else
	window = GameWindow.new(10, WIDTH - 35 - 10, socket)
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
