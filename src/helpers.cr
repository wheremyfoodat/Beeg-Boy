def loadROM (dir : String)
    return File.read(dir).bytes
end

def isBitSet (num, bit): Bool
    return (num & (1 << bit)) != 0
end

def setBit (num, bit, status : Bool)
    if status != isBitSet(num, bit)
        return num ^ (1 << bit)
    end
    
    return num
end

struct Bool
    def to_u8
        return self ? 1_u8 : 0_u8
    end

    def to_u16
        return self ? 1_u16 : 0_u16
    end
end