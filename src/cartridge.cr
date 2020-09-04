require "./helpers"

abstract class Cartridge
    abstract def readROM (addr)
    abstract def readERAM (addr)
    abstract def writeROM (addr, value)
    abstract def writeERAM (addr, value)

    def getRAMSize (val) : UInt32
        sizes = [0_u32, 2048_u32, 8192_u32, 32768_u32, 131072_u32, 65536_u32]
        return sizes[val]
    end

    def getROMSize (val) : UInt32
        return (32_u32 * 1024_u32) << val.to_u32
    end
end

class MBC0 < Cartridge
    def initialize (@rom : Array(UInt8))
    end

    def readROM (addr)
        return @rom[addr]
    end

    def readERAM (addr)
        puts "eRAM accessed but no eRAM available!!!"
        return 0xFF_u8
    end

    def writeROM (addr, value)
        puts "Write to ROM! (MBC?)"
    end

    def writeERAM (addr, value)
        puts "eRAM accessed but no eRAM available!!!"
        return 0xFF_u8
    end
end

class MBC3 < Cartridge

    @bank1Index: UInt32 = 16_u32 * 1024_u32
    @ramIndex: UInt32 = 0

    @ramEnable = false
    @ramSize : UInt32

    def initialize (@rom : Array(UInt8))
        @ramSize = getRAMSize (@rom[0x149])
        @ram = Array(UInt8).new(@ramSize, 0_u8)
    end

    def readROM (addr)
        if addr < 0x4000
            return @rom[addr]
        else
            return @rom[@bank1Index + (addr & 0x3FFF)]
        end
    end

    def readERAM (addr)
        if !@ramEnable
            return 0xFF_u8
        end

        return @ram [@ramIndex + (addr & 0x1FFF)]
    end

    def writeROM (addr, value)
        case addr
        when 0..0x1FFF
            @ramEnable = (value == 0x0A)
        
        when 0x2000..0x3FFF
            bank = value & 0xFF
            bank = (bank == 0) ? bank + 1 : bank # If you try to load bank 0, bank 1 is loaded instead
            @bank1Index = (bank.to_u32 * 16_u32 * 1024_u32)
        
        when 0x4000..0x5FFF
            if value < 4
                @ramIndex = value.to_u32 * (8_u32 * 1024_u32)
            end
        end
    end

    def writeERAM (addr, value)
        if @ramEnable
            @ram [@ramIndex + (addr & 0x1FFF)] = value
        end
    end
end

class MBC5 < Cartridge

    @bank1Index: UInt32 = 16_u32 * 1024_u32
    @ramEnable = false

    def initialize (@rom : Array(UInt8))
    end

    def readROM (addr)
        return @rom[addr]
    end

    def readERAM (addr)
        puts "eRAM accessed but no eRAM available!!!"
        return 0xFF_u8
    end

    def writeROM (addr, value)
        puts "Write to ROM! (MBC5)"
    end

    def writeERAM (addr, value)
        puts "eRAM accessed but no eRAM available!!!"
        return 0xFF_u8
    end
end