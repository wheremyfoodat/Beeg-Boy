require "./cpu"

class CPU
    def dispatchInterrupt (irqVector : UInt16)
        push (@regs.pc)
        @regs.pc = irqVector
        @ime = false
        @cycles += 20
    end

    def handleInterrupts ()
        irqVector = 0_u16
        enabledInterrupts = @mem.ie
        overlappingInterrupts = (enabledInterrupts & @mem.get_if) != 0

        if overlappingInterrupts
            @halt = false

            if @ime
                if @mem.ppu.vBlankIRQRequest && isBitSet(enabledInterrupts, 0)
                    @mem.ppu.vBlankIRQRequest = false
                    irqVector = 0x40_u16

                elsif @mem.ppu.statIRQRequest && isBitSet(enabledInterrupts, 1)
                    @mem.ppu.statIRQRequest = false
                    irqVector = 0x48_u16

                elsif @mem.timers.timaIRQRequest && isBitSet(enabledInterrupts, 2)
                    @mem.timers.timaIRQRequest = false
                    irqVector = 0x50_u16

                elsif @mem.serialIRQRequest && isBitSet(enabledInterrupts, 3)
                    @mem.serialIRQRequest = false
                    irqVector = 0x58_u16
                
                elsif @mem.joypadIRQRequest && isBitSet(enabledInterrupts, 4)
                    @mem.joypadIRQRequest = false
                    irqVector = 0x60_u16
                end

                dispatchInterrupt (irqVector)
            end
        end
    end
end