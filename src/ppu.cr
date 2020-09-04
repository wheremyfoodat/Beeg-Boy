require "crsfml"

enum PPUModes
    HBlank
    VBlank
    OAM
    LCDTransfer
end

class Sprite

    property x : Int16
    property y : Int16
    property tileNum : UInt8

    property priority : Bool
    property xFlip : Bool
    property yFlip : Bool
    property palNumber : Bool

    def initialize (ypos, xpos, tileNum, attributes)
        @y = ypos.to_i16 - 16
        @x = xpos.to_i16 - 8
        @tileNum = tileNum

        @priority = isBitSet(attributes, 7)
        @yFlip = isBitSet(attributes, 6)
        @xFlip = isBitSet(attributes, 5)
        @palNumber = isBitSet(attributes, 4)# 0 = OBP0, 1 = OBP1
    end
end

class PPU
    SIZE_OF_TILE = 16
    SIZE_OF_LINE = 2

    property ly  :  UInt8 = 0 
    property lyc :  UInt8 = 0

    property lcdc : UInt8 = 0
    property stat : UInt8 = 0

    property scy :  UInt8 = 0
    property scx :  UInt8 = 0

    property bgp  :  UInt8 = 0
    property obp0 :  UInt8 = 0
    property obp1 :  UInt8 = 0

    property wx : UInt8 = 0
    property wy : UInt8 = 0

    property statIRQRequest = false
    property vBlankIRQRequest = false

    property vram = Array(UInt8).new(8 * 1024, 0)
    property oam  = Array(UInt8).new(0xA0, 0)

    @currentCycles = 0
    @ppuDisabled = true
    @currentMode = PPUModes::OAM

    @pixels = Array(UInt8).new(160*144*4, 255) # Our framebuffer
    @texture = SF::Texture.new(160, 144)       # Texture used to display the framebuffer on-screen
    @framebufferIndex : UInt32 = 0

    def initialize (@window : SF::RenderWindow)
        changeMode (PPUModes::OAM)
    end

    def step (cycles)

        if (@ppuDisabled) # if the LCD and the PPU are disabled
            return
        end

        @currentCycles += cycles

        case @currentMode
        when PPUModes::OAM
            if (@currentCycles >= 80)
                @currentCycles -= 80
                changeMode(PPUModes::LCDTransfer)
            end
            
        when PPUModes::LCDTransfer
            if (@currentCycles >= 172)
                @currentCycles -= 172
                changeMode(PPUModes::HBlank)
            end
            
        when PPUModes::HBlank
            if (@currentCycles >= 204)
                @currentCycles -= 204
                @ly += 1
                if @ly == 0x90
                    changeMode(PPUModes::VBlank)
                else
                    changeMode(PPUModes::OAM)
                end
                compareLYC()
            end
            
        when PPUModes::VBlank
            if (@currentCycles >= 456)
                @currentCycles -= 456
                @ly += 1
                    
                if @ly == 154
                    changeMode (PPUModes::OAM)
                    @ly = 0
                end

                compareLYC()
            end
        end
    end

    def renderScanline ()
        renderBG()
        renderOBJs()
    end

    def renderBG ()
        @framebufferIndex = (@ly.to_u32 * 160 * 4)
        x = 0
        y = @ly.to_u16 + @scy.to_u16

        win_x = @wx.to_i16 - 7_u16
        win_y = @wy

        renderWindow = (win_y <= @ly && isBitSet(@lcdc, 5))

        bgTileMapBase = (isBitSet(@lcdc, 3)) ? 0x9C00_u16 : 0x9800_u16
        tileDataBase = (isBitSet(@lcdc,4)) ? 0x8000_u16 : 0x8800_u16
        winTileMapBase = (isBitSet(@lcdc, 6)) ? 0x9C00_u16 : 0x9800_u16
        
        while x < 160

            tileLine : UInt16 = 0
            tile_x = 0

            if (renderWindow && win_x <= x && isBitSet(@lcdc, 0)) # render window if you should
                
                y = @ly - @wy
                temp_x = x - win_x

                tile_x = temp_x & 7
                tile_y = y & 7

                tileIndex = readVRAM (winTileMapBase + (((y.to_u16 >> 3) << 5) & 0x3FF) + ((temp_x.to_u16 >> 3)))
                if tileDataBase == 0x8000_u16
                    tileLine = readVRAM16 (tileDataBase + (tileIndex.to_u16 << 4) + (tile_y.to_u16 << 1))
                else
                    tileLine = readVRAM16 (0x9000_u16 + (tileIndex.to_i8!.to_i16) * 16 + (tile_y.to_u16 << 1))
                end

            elsif (isBitSet(@lcdc, 0)) # render BG
                y = @ly.to_u16 + @scy.to_u16
                tile_y = y & 7
                
                p = (x + @scx)
                tile_x = p & 7

                tileIndex = readVRAM (bgTileMapBase + (((y >> 3) << 5) & 0x3FF) + ((p >> 3) & 31))

                if tileDataBase == 0x8000_u16
                    tileLine = readVRAM16 (tileDataBase + (tileIndex.to_u16 << 4) + (tile_y.to_u16 << 1))
                else
                    tileLine = readVRAM16 (0x9000_u16 + (tileIndex.to_i8!.to_i16) * 16 + (tile_y.to_u16 << 1))
                end
            end

            highByte = (tileLine >> 8)
            lowByte = tileLine & 0xFF

            color = (isBitSet(highByte, 7-tile_x).to_u8 << 1) | isBitSet(lowByte, 7-tile_x).to_u8
            color = getColorFromPalette(color, @bgp) 

            set_color(color, @framebufferIndex)
            
            #if (isBitSet(@lcdc, 5))
            #    @pixels[@framebufferIndex] = 255
            #    @pixels[@framebufferIndex+1] = 0
            #    @pixels[@framebufferIndex+2] = 0
            #    @pixels[@framebufferIndex+3] = 255
            #end
            
            x += 1
            @framebufferIndex += 4
        end
    end

    def renderOBJs ()

        if !isBitSet(@lcdc, 1) # if OBJs are disabled
            return
        end

        screen_y = @ly

        sprites = [] of Sprite
        sprite_size = (isBitSet(@lcdc, 2) ? 16 : 8) # Height of sprites depending on LCDC

        i = 0
        while i < 0xA0 && sprites.size < 10 # Fetch 10 first sprites that can be rendered on this line
            sprite_startY: Int16 = @oam[i].to_i16 - 16
            sprite_endY : Int16 = sprite_startY + sprite_size

            if sprite_startY <= screen_y && screen_y < sprite_endY
                sprites << Sprite.new(@oam[i], @oam[i+1], @oam[i+2], @oam[i+3])
            end

            i += 4
        end

        if isBitSet(@lcdc, 2)
            #raise "Beeg sprite\n"
            return
        end

        sprites.each {|sprite|
            if sprite.x >= 0 && sprite.x <= 160
                i = 0
                tile_y = (sprite.yFlip) ? 7 - (screen_y-sprite.y) : ((screen_y-sprite.y) & 7)
                pal = (sprite.palNumber) ? @obp1 : @obp0

                @framebufferIndex = (@ly.to_u32 * 160 * 4 + sprite.x.to_u32 * 4)

                while i < 8
                    tileLine : UInt16 = readVRAM16(0x8000_u16 + (sprite.tileNum.to_u16 << 4) + (tile_y.to_u16 << 1))
                    tile_x = (sprite.xFlip) ? 7 - i : i # TODO: ADD SCX PLZ

                    highByte = (tileLine >> 8)
                    lowByte = tileLine & 0xFF
                    color = (isBitSet(highByte, 7-tile_x).to_u8 << 1) | isBitSet(lowByte, 7-tile_x).to_u8
                    colorID = getColorFromPalette(color, pal) 

                    if (canSpriteBeDrawn(sprite.priority, @framebufferIndex) && sprite.x + i <= 160 && color != 0) # Checks OBJ to BG priority to see if a sprite can be drawn on this pixel
                        set_color(colorID, @framebufferIndex)
                        #@pixels [@framebufferIndex] = 255
                        #@pixels [@framebufferIndex+1] = 0
                        #@pixels [@framebufferIndex+2] = 0
                        #@pixels [@framebufferIndex+3] = 255
                    end

                    @framebufferIndex += 4
                    i += 1
                end
            end
        }
    end

    def renderBuffer ()
        @texture.update (@pixels.to_unsafe.as(UInt8*))
        sprite = SF::Sprite.new (@texture)

        @window.clear()
        @window.draw(sprite)
        @window.display()
    end

    def readVRAM(addr : UInt16)
        return @vram[addr & 0x1FFF]
    end

    def readVRAM16 (addr : UInt16)
        return (readVRAM(addr + 1).to_u16 << 8) | readVRAM (addr)
    end

    def getColorFromPalette (color, palette)
       return (palette >> (color << 1)) & 3
    end

    def changeMode (mode : PPUModes)
        case mode
        
        when PPUModes::LCDTransfer
            @currentMode = PPUModes::LCDTransfer
            @stat = (@stat & 0xFC) | 3

        when PPUModes::HBlank
            renderScanline()
            @currentMode = PPUModes::HBlank
            @stat = @stat & 0xFC

            if isBitSet(@stat, 3)
                @statIRQRequest = true
            end

        when PPUModes::OAM
            @currentMode = PPUModes::OAM
            @stat = (@stat & 0xFC) | 2
            
            if isBitSet(@stat, 5)
                @statIRQRequest = true
            end

        when PPUModes::VBlank
            renderBuffer()
            @currentMode = PPUModes::VBlank
            @vBlankIRQRequest = true
            @stat = (@stat & 0xFC) | 1

            if (isBitSet(@stat, 4))
                @statIRQRequest = true
            end
        end
    end

    def compareLYC
        @stat = setBit(@stat, 2, @lyc == @ly)
        if (@lyc == @ly && isBitSet(@stat, 6))
            @statIRQRequest = true
        end
    end

    def writeLCDC (value)
        @lcdc = value
        if (!isBitSet(value, 7))
            @stat = @stat & 0xFC
            @ppuDisabled = true
            @ly = 0

        elsif (@ppuDisabled)
            @ppuDisabled = false
            changeMode (PPUModes::OAM)
        end 
    end

    def set_color (color, framebufferIndex)
        case color
            
            when 0
                @pixels[@framebufferIndex] = 247
                @pixels[@framebufferIndex + 1] = 190
                @pixels[@framebufferIndex + 2] = 247

            when 1
                @pixels[@framebufferIndex] = 231
                @pixels[@framebufferIndex + 1] = 134
                @pixels[@framebufferIndex + 2] = 134

            when 2
                @pixels[@framebufferIndex] = 119
                @pixels[@framebufferIndex + 1] = 51
                @pixels[@framebufferIndex + 2] = 231
            
            when 3
                @pixels[@framebufferIndex] = 44
                @pixels[@framebufferIndex + 1] = 44
                @pixels[@framebufferIndex + 2] = 150
            end

            @pixels[@framebufferIndex + 3] = 255 # This is the "alpha" of the pixel. Since there is no transparency on the GB, it's always 255
    end

    def canSpriteBeDrawn (priority, framebufferIndex) # Checks OBJ to BG priority to see if sprite is above BG
        if !priority
            return true
        else
            return @pixels[framebufferIndex] == 247 && @pixels[framebufferIndex+1] == 190 && @pixels[framebufferIndex+2] == 247
        end
    end
end