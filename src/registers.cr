# Should prolly move this into the CPU file

class Registers 

    property a = 0_u8
    property b = 0_u8
    property c = 0_u8
    property d = 0_u8
    property e = 0_u8
    property h = 0_u8
    property l = 0_u8

    property zero = false
    property sub = false
    property half_carry = false
    property carry = false

    property pc = 0_u16
    property sp = 0_u16

    def af : UInt16
        return (@a.to_u16) << 8 | zero.to_u8 << 7 | sub.to_u8 << 6 | half_carry.to_u8 << 5 | carry.to_u8 << 4
    end

    def bc : UInt16
        return (@b.to_u16) << 8 | @c
    end

    def de : UInt16
        return (@d.to_u16) << 8 | @e
    end

    def hl : UInt16
        return (@h.to_u16) << 8 | @l
    end

    def af=(val : UInt16)
        @a = (val >> 8).to_u8
        @zero = isBitSet(val, 7)
        @sub  = isBitSet(val, 6)
        @half_carry = isBitSet(val, 5)
        @carry  = isBitSet(val, 4)
    end

    def bc=(val : UInt16)
        @b = (val >> 8).to_u8
        @c = (val & 0xFF).to_u8
    end

    def de=(val : UInt16)
        @d = (val >> 8).to_u8
        @e = (val & 0xFF).to_u8
    end

    def hl=(val : UInt16)
        @h = (val >> 8).to_u8
        @l = (val & 0xFF).to_u8
    end
end