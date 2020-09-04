require "crsfml"
require "./ppu"
require "./timers"
require "./memory"
require "./cpu"

class Gameboy
    CYCLES_PER_FRAME = 4194300

    def initialize (dir : String, @window : SF::RenderWindow)
        @ppu = PPU.new(window)
        @timers = Timers.new()
        @joypad = Joypad.new()
        @mem = Memory.new(@ppu, @timers, @joypad, dir)
        @cpu = CPU.new(@mem)
    end

    def step
        @cpu.executeInstruction()
        @ppu.step (@cpu.cycles)
        @timers.update (@cpu.cycles)
    end

    def runFrame
        while @cpu.total_cycles < CYCLES_PER_FRAME
            self.step()
        end

        @cpu.total_cycles -= CYCLES_PER_FRAME

        while event = @window.poll_event # Poll SFML events at the end of the frame so that the window doesn't lock
            if event.is_a? SF::Event::Closed
                @window.close
                exit (0)
            end
        end
    end

    def mem
        @mem
    end

    def cpu
        @cpu
    end
end