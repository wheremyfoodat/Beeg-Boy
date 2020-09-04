require "./memory"
require "./registers"
require "./irqs"

INSTRUCTION_CYCLES = [
    #0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    4,  12,  8,  8,  4,  4,  8,  4, 20,  8,  8,  8,  4,  4,  8,  4, #0
	4,  12,  8,  8,  4,  4,  8,  4, 12,  8,  8,  8,  4,  4,  8,  4, #1
    8,  12,  8,  8,  4,  4,  8,  4,  8,  8,  8,  8,  4,  4,  8,  4, #2
    8,  12,  8,  8, 12, 12, 12,  4,  8,  8,  8,  8,  4,  4,  8,  4, #3 
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #4
	4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #5
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #6
    8,  8,  8,  8,  8,  8,  4,  8,  4,  4,  4,  4,  4,  4,  8,  4, #7
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #8
	4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #9
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #A
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #B
    8,  12, 12, 16, 12, 16, 8, 16,  8, 16,  12,  0,  12,  24,  8, 16, #C
	8,  12, 12, 0, 12, 16, 8, 16,  8, 16,  12,  0,  12, 0,  8, 16, #D
    12, 12,  8, 0, 0, 16, 8, 16, 16,  4, 16, 0, 0, 0,  8, 16, #E
    12, 12,  8, 4, 0, 16, 8, 16, 12,  8, 16, 4, 0, 0,  8, 16  #F
]

CB_INSTRUCTION_CYCLES = [
    #0 1 2 3 4 5  6 7 8 9 A B C D  E  F
	8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #0
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #1
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #2
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #3                                    
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #4
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #5
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #6
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #7                                               
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #8
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #9
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #A
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #B                                               
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #C
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #D
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #E
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8  #F
]

class CPU
    property cycles = 0
    property total_cycles = 0
    
    def initialize(@mem : Memory)
        @regs = Registers.new()
        @ime = false
        @halt = false
        @LogFile = File.open("./ROMs/EpicLog.txt", "w")
    end

    def executeInstruction()

        @cycles = 0
        handleInterrupts()
        #if @regs.pc >= 0x100
        #   @LogFile.printf("A: %02X F: %02X B: %02X C: %02X D: %02X E: %02X H: %02X L: %02X SP: %04X PC: 00:%04X (%02X %02X %02X %02X)\n", @regs.a, @regs.af & 0xFF, @regs.b, @regs.c, @regs.d, @regs.e, @regs.h, @regs.l, @regs.sp, @regs.pc, @mem.readByte(@regs.pc), @mem.readByte(@regs.pc+1), @mem.readByte(@regs.pc+2), @mem.readByte(@regs.pc+3))
        #end
        
        if (!@halt)
            opcode = nextByte()
            @cycles += INSTRUCTION_CYCLES [opcode]
            execute_opcode (opcode)
        else
            @cycles = 4 # CPU is stalled, PPU/APU/Timers keep advancing
        end

        @total_cycles += cycles
    end

    def nextByte()
        val = @mem.readByte (@regs.pc)
        @regs.pc += 1
        return val
    end

    def nextWord()
        val = @mem.readWord (@regs.pc)
        @regs.pc += 2
        return val
    end

    def getRegister (val) : UInt8
        case (val & 0x7)
        
        when 0
            @regs.b
        when 1
            @regs.c
        when 2
            @regs.d
        when 3
            @regs.e
        when 4
            @regs.h
        when 5
            @regs.l
        when 6
            @mem.readByte(@regs.hl)
        else
            @regs.a
        end
    end

    def setRegister (registerNum, value)
        case registerNum & 7
        when 0
            @regs.b = value
        when 1
            @regs.c = value
        when 2
            @regs.d = value
        when 3
            @regs.e = value
        when 4
            @regs.h = value
        when 5
            @regs.l = value
        when 6
            @mem.writeByte(@regs.hl, value)
        else
            @regs.a = value
        end
    end

    def pop ()
        val = @mem.readWord(@regs.sp)
        @regs.sp &+= 2
        return val
    end

    def push (val)
        @regs.sp &-= 2
        @mem.writeWord(@regs.sp, val)
    end

    def getCondition (op, isJMP = false) # For RET, CALL, JMP. Not for JR
        if (isBitSet(op, 0))
            return true
        end

        cond = (op >> 3) & 3
        res = false
        case cond
        when 0
            res = !@regs.zero
        when 1
            res = @regs.zero
        when 2
            res = !@regs.carry
        else
            res = @regs.carry
        end

        if (res && isJMP)
            @cycles += 4
        elsif res
            @cycles += 12
        end

        return res
    end

    def ret (opcode)
        if (getCondition(opcode))
            @regs.pc = pop()
        end
    end

    def jmp (opcode)
        @regs.pc = (getCondition(opcode, true)) ? nextWord() : @regs.pc &+ 2
    end

    def call (opcode)
        addr = nextWord()
        if (getCondition(opcode))
            push (@regs.pc)
            @regs.pc = addr
        end
    end

    def jr (opcode)
        cond = false
        if (opcode == 0x18) # JR i8
            cond = true
        else
            cond = getCondition(opcode, true)
        end

        offset = nextByte().to_i8!
        if cond
            @regs.pc &+= offset
        end 
    end

    def add (operand2)
        result = @regs.a &+ operand2

        @regs.zero = (result == 0)
        @regs.carry = result < @regs.a
        @regs.half_carry = (@regs.a & 0xF) + (operand2 & 0xF) > 0xF
        @regs.sub = false

        @regs.a = result
    end

    def adc (operand2)
        result = @regs.a.to_u16 &+ operand2.to_u16 &+ @regs.carry.to_u16

        @regs.zero = ((result & 0xFF) == 0)

        if @regs.carry 
            @regs.half_carry = (@regs.a & 0xF) + (operand2 & 0xF) >= 0xF
        else
            @regs.half_carry = (@regs.a & 0xF) + (operand2 & 0xF) > 0xF
        end

        @regs.carry = isBitSet(result, 8)
        @regs.sub = false
        @regs.a = (result & 0xFF).to_u8
    end

    def addHL (operand2 : UInt16)
        @regs.sub = false
        @regs.carry = isBitSet(@regs.hl.to_u32 + operand2.to_u32, 16)
        @regs.half_carry = (@regs.hl & 0xFFF) + (operand2 & 0xFFF) > 0xFFF

        @regs.hl &+= operand2
    end

    def sub (operand2)
        result = @regs.a &- operand2
        @regs.zero = (result == 0)
        @regs.carry = result > @regs.a
        @regs.sub = true
        @regs.half_carry = (@regs.a & 0xF) < (operand2 & 0xF)

        @regs.a = result
    end

    def sbc (operand2)
        old_carry = @regs.carry.to_u8
        result = @regs.a.to_u16 &- operand2.to_u16 &- old_carry.to_u16

        if !@regs.carry
            @regs.half_carry = (@regs.a & 0xF) < (operand2 & 0xF)
        else
            @regs.half_carry = (@regs.a & 0xF) < (operand2 & 0xF) + old_carry
        end

        @regs.carry = isBitSet(result, 8)
        @regs.sub = true
        @regs.zero = ((result & 0xFF) == 0)
        @regs.a = (result & 0xFF).to_u8
    end

    def cp (operand2)
        result = @regs.a &- operand2
        @regs.zero = (result == 0)
        @regs.carry = result > @regs.a
        @regs.sub = true
        @regs.half_carry = (@regs.a & 0xF) < (operand2 & 0xF)
    end

    def or (operand2)
        @regs.a |= operand2
        @regs.zero = (@regs.a == 0)
        @regs.carry = false
        @regs.half_carry = false
        @regs.sub = false
    end

    def and (operand2)
        @regs.a &= operand2
        @regs.zero = (@regs.a == 0)
        @regs.carry = false
        @regs.half_carry = true
        @regs.sub = false
    end

    def xor (operand2)
        @regs.a ^= operand2
        @regs.zero = (@regs.a == 0)
        @regs.carry = false
        @regs.half_carry = false
        @regs.sub = false
    end

    def inc (num)
        result = num &+ 1
        @regs.zero = (result == 0)
        @regs.sub = false
        @regs.half_carry = (num & 0xF) == 0xF
        return result
    end

    def dec (num)
        result = num &- 1
        @regs.zero = (result == 0)
        @regs.sub = true
        @regs.half_carry = (num & 0xF) == 0
        return result
    end

    def bit (opcode)
        num = getRegister(opcode)
        bit = (opcode >> 3) & 0x7

        @regs.zero = !isBitSet(num, bit)
        @regs.half_carry = true
        @regs.sub = false
    end

    def set (opcode)
        num = getRegister(opcode)
        bit = (opcode >> 3) & 0x7
        num = setBit(num, bit, true)
        setRegister(opcode & 7, num)
    end

    def res (opcode)
        num = getRegister(opcode)
        bit = (opcode >> 3) & 0x7
        num = setBit(num, bit, false)
        setRegister(opcode & 7, num)
    end

    def sra (opcode)
        num = getRegister(opcode)
        @regs.carry = isBitSet(num, 0)
        num = (num >> 1) | (num & 0x80)
        @regs.zero = (num == 0)
        @regs.sub = false
        @regs.half_carry = false

        setRegister(opcode & 7, num)
    end

    def sla (opcode)
        num = getRegister (opcode)
        @regs.carry = isBitSet(num, 7)
        num = num << 1
        @regs.zero = (num == 0)
        @regs.sub = false
        @regs.half_carry = false

        setRegister(opcode & 7, num)
    end

    def rlc (opcode)
        num = getRegister(opcode)
        @regs.carry = isBitSet(num, 7)
        num = (num << 1) | (num >> 7)
        @regs.zero = (num == 0)
        @regs.sub = false
        @regs.half_carry = false

        setRegister(opcode & 7, num)
    end

    def rrc (opcode)
        num = getRegister(opcode)
        @regs.carry = isBitSet(num, 0)
        num = (num >> 1) | (num << 7)
        @regs.zero = (num == 0)
        @regs.sub = false
        @regs.half_carry = false

        setRegister(opcode & 7, num)
    end

    def srl (opcode)
        num = getRegister(opcode)
        @regs.carry = isBitSet(num, 0)
        num = (num >> 1)
        @regs.zero = (num == 0)
        @regs.sub = false
        @regs.half_carry = false

        setRegister(opcode & 7, num)
    end

    def swap (opcode)
        num = getRegister(opcode)
        num = (num >> 4) | (num << 4)
        @regs.zero = (num == 0)
        @regs.sub = false
        @regs.half_carry = false
        @regs.carry = false

        setRegister(opcode & 7, num)
    end

    def rl (opcode)
        operand = getRegister(opcode)
        old_carry = @regs.carry
        @regs.carry = isBitSet(operand, 7) 

        result = (operand << 1) | old_carry.to_u8
        @regs.zero = (result == 0)
        @regs.sub = false
        @regs.half_carry = false

        setRegister(opcode & 7, result)
    end

    def rr (opcode)
        operand = getRegister(opcode)
        old_carry = @regs.carry
        @regs.carry = isBitSet(operand, 0) 

        result = (operand >> 1) | (old_carry.to_u8 << 7)        
        @regs.zero = (result == 0)
        @regs.sub = false
        @regs.half_carry = false

        setRegister(opcode & 7, result)
    end

    def execute_opcode (opcode)
        
        case opcode

        when 0   # NOP

        when 0x6, 0x16, 0x26, 0x36, 0xE, 0x1E, 0x2E, 0x3E # LD reg, (u8)
            registerNum = (opcode >> 3) & 7
            setRegister(registerNum, nextByte())

        when 0x8 # LD (u16), SP
            @mem.writeWord(nextWord(), @regs.sp)
        
        when 0x1 # LD BC, u16
            @regs.bc = nextWord()
        
        when 0x11 # LD DE, u16
            @regs.de = nextWord()
        
        when 0x21 # LD HL, u16
            @regs.hl = nextWord()

        when 0x31 # LD SP, u16
            @regs.sp = nextWord()

        when 0x2 # LD (BC), a
            @mem.writeByte(@regs.bc, @regs.a)

        when 0x12 # LD (DE), a
            @mem.writeByte(@regs.de, @regs.a)

        when 0x22 # LD (HL++), a
            @mem.writeByte(@regs.hl, @regs.a)
            @regs.hl &+= 1

        when 0x32 # LD (HL--), a
            @mem.writeByte(@regs.hl, @regs.a)
            @regs.hl &-= 1

        when 0xA # LD a, (BC)
            @regs.a = @mem.readByte (@regs.bc)

        when 0x1A # LD a, (DE)
            @regs.a = @mem.readByte (@regs.de)

        when 0x2A # LD a, (HL+)
            @regs.a = @mem.readByte (@regs.hl)
            @regs.hl &+= 1

        when 0x3A # LD a, (HL-)
            @regs.a = @mem.readByte (@regs.hl)
            @regs.hl &-= 1
        
        when 0x07 # RLCA
            @regs.zero = false
            @regs.half_carry = false
            @regs.sub = false
            @regs.carry = isBitSet(@regs.a, 7)

            @regs.a = @regs.a << 1 | @regs.a >> 7
            
        when 0xF # RRCA
            @regs.carry = isBitSet(@regs.a, 0)
            @regs.zero = false
            @regs.sub = false
            @regs.half_carry = false

            @regs.a = (@regs.a >> 1) | (@regs.carry.to_u8 << 7)

        when 0x17 # RLA
            oldC = @regs.carry.to_u8
            @regs.carry = isBitSet(@regs.a, 7)
            @regs.a = (@regs.a << 1) | oldC

            @regs.zero = false
            @regs.sub = false
            @regs.half_carry = false
        
        when 0x1F # RRA
            oldC = @regs.carry.to_u8
            @regs.carry = isBitSet(@regs.a, 0)
            @regs.a = @regs.a >> 1 | oldC << 7

            @regs.zero = false
            @regs.sub = false
            @regs.half_carry = false

        when 0x27 # DAA oh shit..
            if (@regs.sub)
                if (@regs.carry)
                    @regs.a &-= 0x60
                    @regs.carry = true
                end

                if (@regs.half_carry)
                    @regs.a &-= 0x6
                end

            else
                if (@regs.carry || @regs.a > 0x99)
                    @regs.a &+= 0x60
                    @regs.carry = true
                end

                if (@regs.half_carry || (@regs.a & 0xF) > 0x9)
                    @regs.a &+= 0x6
                end
            end

            @regs.zero = (@regs.a == 0)
            @regs.half_carry = false

        when 0x80..0x87 # add a, r
            operand2 = getRegister(opcode)
            add (operand2)

        when 0xC6
            add (nextByte())

        when 0x88..0x8F # adc a, r
            operand2 = getRegister(opcode)
            adc (operand2)

        when 0xCE # adc a, (u8)
            adc (nextByte())

        when 0x90..0x97 # sub a, r
            operand2 = getRegister(opcode)
            sub (operand2)

        when 0xD6 # sub a, (u8)
            sub(nextByte())

        when 0x98..0x9F # sbc a, r
            operand2 = getRegister(opcode)
            sbc (operand2)

        when 0xDE # sbc a, (u8)
            sbc (nextByte())
        
        when 0xA0..0xA7 # and a, r
            operand2 = getRegister(opcode)
            and (operand2)

        when 0xE6 # and a, (u8)
            and (nextByte())

        when 0xA8..0xAF # xor a, r
            operand2 = getRegister(opcode)
            xor (operand2)
 
        when 0xEE # xor a, (u8)
            xor(nextByte())

        when 0xB0..0xB7 # or a, r
            operand2 = getRegister(opcode)
            or (operand2)

        when 0xF6 # or a, (u8)
            or (nextByte())
        
        when 0xB8..0xBF # cp a, r
            operand2 = getRegister(opcode)
            cp (operand2)

        when 0xFE # cp a, u8
            cp (nextByte())

        when 0x2F # cpl
            @regs.a = ~@regs.a
            @regs.half_carry = true
            @regs.sub = true
        
        when 0x37 # SCF
            @regs.carry = true
            @regs.half_carry = false
            @regs.sub = false

        when 0x3F # CCF
            @regs.carry = !@regs.carry
            @regs.half_carry = false
            @regs.sub = false
        
        when 0x4, 0x14, 0x24, 0x34, 0xC, 0x1C, 0x2C, 0x3C # INC
            registerNum = (opcode >> 3) & 7
            setRegister(registerNum, inc(getRegister(registerNum)))

        when 0x3 # INC BC
            @regs.bc &+= 1

        when 0x13 # INC DE
            @regs.de &+= 1

        when 0x23 # INC HL
            @regs.hl &+= 1

        when 0x33 # INC SP
            @regs.sp &+= 1

        when 0x9 # ADD HL, BC
            addHL (@regs.bc)

        when 0x19 # ADD HL, DE
            addHL (@regs.de)

        when 0x29 # ADD HL, HL
            addHL (@regs.hl)

        when 0x39 # ADD HL, SP
            addHL (@regs.sp)

        when 0x5, 0x15, 0x25, 0x35, 0xD, 0x1D, 0x2D, 0x3D # DEC
            registerNum = (opcode >> 3) & 7
            setRegister(registerNum, dec(getRegister(registerNum)))

        when 0xB # DEC BC
            @regs.bc &-= 1

        when 0x1B # DEC DE
            @regs.de &-= 1

        when 0x2B # DEC HL
            @regs.hl &-= 1

        when 0x3B # DEC SP
            @regs.sp &-= 1

        when 0x40..0x75, 0x77..0x7F # LD r, r
            source = getRegister(opcode)
            dest = (opcode >> 3) & 7
            setRegister(dest, source)

        when 0xEA # LD (u16), a
            @mem.writeByte(nextWord(), @regs.a)

        when 0xFA # LD a, (u16)
            @regs.a = @mem.readByte(nextWord())

        when 0x18, 0x28, 0x38, 0x20, 0x30 # JR
            jr (opcode)

        when 0xC0, 0xD0, 0xC8, 0xC9, 0xD8 # RET
            ret(opcode)
        
        when 0xC2, 0xD2, 0xC3, 0xCA, 0xDA # JMP
            jmp(opcode)
        
        when 0xC4, 0xD4, 0xCC, 0xDC, 0xCD # CALL
            call(opcode)

        when 0xD9 # RETI
            @ime = true
            @regs.pc = pop()

        when 0xC7, 0xD7, 0xE7, 0xF7, 0xCF, 0xDF, 0xEF, 0xFF # RST
            push(@regs.pc)
            @regs.pc = (opcode & 0x38).to_u16 # RST Format: xxEXPxxx
                                     # Function: Push PC. Jump to address 00EXP000

        when 0xE9 # JP HL
            @regs.pc = @regs.hl

        when 0xC5 # PUSH BC
            push (@regs.bc)

        when 0xD5 # PUSH DE
            push (@regs.de)

        when 0xE5 # PUSH HL
            push (@regs.hl)

        when 0xF5 # PUSH AF
            push (@regs.af)

        when 0xC1 # POP BC
            @regs.bc = pop()

        when 0xD1 # POP DE
            @regs.de = pop()

        when 0xE1 # POP HL
            @regs.hl = pop()

        when 0xF1 # POP AF
            @regs.af = pop()

        when 0xCB # CB nn
            execute_CB()

        when 0xE0 # LD (FF00 + u8), A
            addr = 0xFF00_u16 + nextByte()
            @mem.writeByte(addr, @regs.a)

        when 0xF0 # LD a, (FF00+u8)
            @regs.a = @mem.readByte (0xFF00_u16 + nextByte())

        when 0xE2 # LD (FF00 + C), A
            @mem.writeByte(0xFF00_u16 + @regs.c, @regs.a)
        
        when 0xF2 # LD A, (FF00 + C)
            @regs.a = @mem.readByte (0xFF00_u16 + @regs.c)

        when 0xF3 # DI
            @ime = false

        when 0xFB # EI
            @ime = true
        
        when 0x76 # HALT
            @halt = true
            #printf ("Halt on the gang gang\n")
        
        when 0xF9 # LD SP, HL
            @regs.sp = @regs.hl

        when 0xE8 # ADD SP, i8
            offset = nextByte
            @regs.carry = isBitSet((@regs.sp & 0xFF) + offset, 8)
            @regs.half_carry = (@regs.sp & 0xF) + (offset & 0xF) > 0xF
            @regs.zero = false
            @regs.sub = false

            @regs.sp &+= offset.to_i8!

        when 0xF8 # LD HL, SP+i8
            offset = nextByte
            @regs.carry = isBitSet((@regs.sp & 0xFF) + offset, 8)
            @regs.half_carry = (@regs.sp & 0xF) + (offset & 0xF) > 0xF
            @regs.zero = false
            @regs.sub = false

            @regs.hl = (@regs.sp &+ offset.to_i8!) 
        else
            raise "Unimplemented opcode at PC #{(@regs.pc - 1).to_s(16)}: #{opcode.to_s(16)}"
        end
    end

    def execute_CB ()
        opcode = nextByte()
        @cycles += CB_INSTRUCTION_CYCLES [opcode]

        case opcode

        when 0x00..0x07 # RLC
            rlc (opcode)
        when 0x08..0x0F # RRC
            rrc (opcode)
        when 0x10..0x17 # RL
            rl (opcode)
        when 0x18..0x1F # RR
            rr (opcode)
        when 0x20..0x27 # SLA
            sla (opcode)
        when 0x28..0x2F # SRA
            sra(opcode)
        when 0x30..0x37 # SWAP
            swap(opcode)
        when 0x38..0x3F # SRL
            srl(opcode)
        when 0x40..0x7F # BIT
            bit (opcode)
        when 0x80..0xBF # RES
            res (opcode)
        when 0xC0..0xFF # SET
            set (opcode)
        else
            raise "Unimplemented opcode at PC #{(@regs.pc - 2).to_s(16)}: CB#{opcode.to_s(16)}"
        end
    end
end
