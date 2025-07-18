require "crsfml"
require "./gameboy"

window = SF::RenderWindow.new(SF::VideoMode.new(160, 144), "Beeg Boy")

gb = Gameboy.new("./ROMs/tst.gb", window)

while true
    gb.runFrame
end

#while window.open?
#  while event = window.poll_event
#    if event.is_a? SF::Event::Closed
#      window.close
#    end
#  end
#end
