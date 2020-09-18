require "./helpers"
require "./cartridge"
require "./ppu"
require "./joypad"
require "./timers"

## Note:
## I'll soon impl a cartridge interface to handle MBCs and shit
## So the ROM/eWRAM shit here will have to go
## Should also find a neater way to handle MMIO soon

class Memory
    @bootrom : Array(UInt8) = loadROM ("./ROMs/bootrom.gb")
    @bootromMapped = true
    @cartridge : Cartridge

    @wram = Array(UInt8).new(8 * 1024, 0)
    @hram = Array(UInt8).new(0x7F, 0)
    @nr50Stub: UInt8 = 0 # Need for Pokemon Red/Blue or else they hang when healing pokemon
    property ie = 0_u8

    property serialIRQRequest = false # Dummy, stays here for now
    property joypadIRQRequest = false # Same here   
    property ppu
    property timers                    

    def get_if
        num  =   @ppu.vBlankIRQRequest.to_u8
        num |=  (@ppu.statIRQRequest.to_u8 << 1)
        num |=  (@timers.timaIRQRequest.to_u8 << 2)
        num |=  (@serialIRQRequest.to_u8 << 3)
        num |=  (@joypadIRQRequest.to_u8 << 4)

        return num
    end

    def interrupt_requests=(val) # Pointers plz
        @ppu.vBlankIRQRequest  = isBitSet(val, 0)
        @ppu.statIRQRequest    = isBitSet(val, 1)
        @timers.timaIRQRequest = isBitSet(val, 2)
        @serialIRQRequest      = isBitSet(val, 3)
        @joypadIRQRequest      = isBitSet(val, 4)
    end

    def initialize (@ppu : PPU, @timers : Timers, @joypad : Joypad, dir : String)
        @cartridge = createCartridge(dir)
    end

    def readByte(addr): UInt8
        case addr
        when 0..0xFF
            if @bootromMapped
                return @bootrom[addr]
            else 
                return @cartridge.readROM(addr)
            end

        when 0x100..0x7FFF
            return @cartridge.readROM(addr)

        when 0x8000..0x9FFF
            return @ppu.vram[addr & 0x1FFF]

        when 0xA000..0xBFFF
            return @cartridge.readERAM (addr)
        
        when 0xC000..0xFDFF                    ## This should handle both WRAM and Echo RAM
            return @wram[addr & 0x1FFF]
    
        when 0xFE00..0xFE9F
            return @ppu.oam[addr & 0x9F]
        
        when 0xFEA0..0xFEFF
            puts "read from invalid address!"
        
        when 0xFF00..0xFF7F
            case addr

            when 0xFF00 # JOYP
                return @joypad.getJoypad

            when 0xFF04 # DIV
                return @timers.div

            when 0xFF05 # TIMA
                return @timers.tima

            when 0xFF24 # NR50
                return @nr50Stub

            when 0xFF40 # LCDC
                return @ppu.lcdc

            when 0xFF41 # LCDC STAT 
                return (@ppu.stat)

            when 0xFF44 # LY
                return @ppu.ly
                #return 0x90_u8

            when 0xFF45 # LYC
                return @ppu.lyc

            when 0xFF42 # SCY
                return @ppu.scy
            
            when 0xFF43 # SCX
                return @ppu.scx

            when 0xFF4A # WY
                return @ppu.wy
            
            when 0xFF4B # WX
                return @ppu.wx
            
            when 0xFF0F
                printf("IF read! Got value: %02X\n", self.get_if)
                return self.get_if

            else
                #puts "unimplemented MMIO read at address " + addr.to_s(16)
            end

        when 0xFF80..0xFFFE
            return @hram[addr & 0x7F]
        
        when 0xFFFF
            return @ie
        end
        return 0xFF_u8
    end

    def writeByte(addr : UInt16, value : UInt8)
        case addr
        when 0..0x7FFF
            @cartridge.writeROM(addr, value)

        when 0x8000..0x9FFF
            @ppu.vram[addr & 0x1FFF] = value

        when 0xA000..0xBFFF
            @cartridge.writeERAM(addr, value)
        
        when 0xC000..0xFDFF                    ## This should handle both WRAM and Echo RAM
            @wram[addr & 0x1FFF] = value
    
        when 0xFE00..0xFE9F
            @ppu.oam[addr & 0x9F] = value
        
        when 0xFEA0..0xFEFF
            #puts "write to invalid address!"
        
        when 0xFF00..0xFF7F
            case addr

            when 0xFF00 # JOYP
                @joypad.handleWrite(value)
            
            when 0xFF01 # Serial output
                #print value.chr

            when 0xFF04 # DIV
                @timers.div = 0

            when 0xFF05
                @timers.tima = value

            when 0xFF06 # TMA
                @timers.tma = value

            when 0xFF07 # TAC
                @timers.tac = value

            when 0xFF24 # NR50
                @nr50Stub = value

            when 0xFF0F # IF
                self.interrupt_requests = value
            
            when 0xFF40 # LCDC
                @ppu.writeLCDC(value)

            when 0xFF41 # STAT
                @ppu.stat = (value & 0b11111000_u8) | (@ppu.stat & 7)

            when 0xFF42 # SCY
                @ppu.scy = value

            when 0xFF43 # SCX
                @ppu.scx = value
            
            when 0xFF45 # LYC
                @ppu.lyc = value

            when 0xFF46 # OAM DMA start address                
                i = 0
                start_addr = (value.to_u16 << 8)
                #printf("OAM DMA starting at %04X\n", start_addr)
                while i < 0xA0
                    @ppu.oam[i] = readByte(start_addr + i)
                    i += 1
                end

            when 0xFF47 # BGP
                @ppu.bgp = value
            
            when 0xFF48 # OBP0
                @ppu.obp0 = value
            
            when 0xFF49 # OBP1
                @ppu.obp1 = value
            
            when 0xFF4A # WY
                @ppu.wy = value
            
            when 0xFF4B # WX
                @ppu.wx = value
            
            when 0xFF50 # Bootrom disable reg
                @bootromMapped = false

            else
                #puts "unimplemented MMIO write at address " + addr.to_s(16)
            end
        
        when 0xFF80..0xFFFE
            @hram[addr & 0x7F] = value
        
        when 0xFFFF
            @ie = value
        end
    end

    def readWord (addr : UInt16): UInt16
        return (readByte (addr + 1)).to_u16 << 8 | readByte(addr)
    end
    
    def writeWord (addr : UInt16, val : UInt16)
        writeByte(addr + 1, (val >> 8).to_u8)
        writeByte(addr, (val & 0xFF).to_u8)
    end

    def createCartridge (dir) : Cartridge
        rom = loadROM (dir)
        cartType = rom[0x147]

        case cartType
        when 0
            return MBC0.new(rom)
        when 0xF..0x13
            return MBC3.new(rom)
        #when 0x19..0x1E
        #    return MBC5.new(rom)
        else
            printf("%02X\n", cartType)
            return MBC0.new(rom)
            #raise "Unimplemented cart type exception\n"
        end
    end
end
