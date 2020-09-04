class Timers

    property tima : UInt8 = 0
    property tma : UInt8 = 0
    property div : UInt8 = 0
    property tac : UInt8 = 0
    property timaIRQRequest = false

    @tima_cycles : UInt16 = 0
    @div_cycles : UInt16 = 0

    @TIMA_THRESHOLDS = [1024, 16, 64, 256]

    def update (cycles)
        if (isBitSet(@tac, 2)) # if the TIMA enable bit in TAC is set
            threshold = @TIMA_THRESHOLDS [@tac & 3]
            @tima_cycles += cycles
            
            while @tima_cycles >= threshold
                @tima_cycles -= threshold
                if (@tima == 0xFF) # if TIMA overflowed
                    @tima = @tma
                    @timaIRQRequest = true
                else
                    @tima &+= 1
                end
            end
        end

        @div_cycles += cycles
        while @div_cycles >= 256
            @div &+= 1
            @div_cycles -= 256
        end
    end
end