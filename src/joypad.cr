require "crsfml"

class Joypad
    @dpadEnable = false
    @buttonEnable = false

    def handleWrite (val)
        @buttonEnable = !isBitSet(val, 5)
        @dpadEnable = !isBitSet(val, 4)
    end

    def getJoypad ()
        num : UInt8 = 0xFF_u8
        num = setBit(num, 5, !@buttonEnable)
        num = setBit(num, 4, !@buttonEnable)

        if (@buttonEnable)
            num = setBit(num, 3, !SF::Keyboard.key_pressed?(SF::Keyboard::Enter))
            num = setBit(num, 2, !SF::Keyboard.key_pressed?(SF::Keyboard::D))
            num = setBit(num, 1, !SF::Keyboard.key_pressed?(SF::Keyboard::A))
            num = setBit(num, 0, !SF::Keyboard.key_pressed?(SF::Keyboard::S))

        elsif (@dpadEnable)
            num = setBit(num, 3, !SF::Keyboard.key_pressed?(SF::Keyboard::Down))
            num = setBit(num, 2, !SF::Keyboard.key_pressed?(SF::Keyboard::Up))
            num = setBit(num, 1, !SF::Keyboard.key_pressed?(SF::Keyboard::Left))
            num = setBit(num, 0, !SF::Keyboard.key_pressed?(SF::Keyboard::Right))
        end

        return num
    end
end