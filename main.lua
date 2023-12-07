-- local love = _G.love
local JM = require "jm-love2d-package.init"
local lgx = love.graphics

function love.load()
    math.randomseed(os.time())
    lgx.setBackgroundColor(0, 0, 0, 1)
    lgx.setDefaultFilter("nearest", "nearest")
    lgx.setLineStyle("rough")
    love.mouse.setVisible(false)

    _G.SCREEN_WIDTH = JM.Utils:round(398) --398
    _G.SCREEN_HEIGHT = JM.Utils:round(224)

    _G.SUBPIXEL = 3
    _G.TILE = 16
    _G.CANVAS_FILTER = "linear"
    _G.TARGET = love.system.getOS()

    JM:get_font():set_font_size(8)

    do
        local Word = require "jm-love2d-package.modules.font.Word"
        ---@diagnostic disable-next-line: inject-field
        Word.eff_wave_range = 1
    end

    return JM:load_initial_state("lib.gamestate.game", false)
end

function love.textinput(t)
    return JM:textinput(t)
end

function love.keypressed(key, scancode, isrepeat)
    return JM:keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    return JM:keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
    return JM:mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    return JM:mousereleased(x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    return JM:mousemoved(x, y, dx, dy, istouch)
end

function love.focus(f)
    return JM:focus(f)
end

function love.visible(v)
    return JM:visible(v)
end

function love.wheelmoved(x, y)
    return JM:wheelmoved(x, y)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    return JM:touchpressed(id, x, y, dx, dy, pressure)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    return JM:touchreleased(id, x, y, dx, dy, pressure)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    return JM:touchmoved(id, x, y, dx, dy, pressure)
end

function love.joystickpressed(joystick, button)
    return JM:joystickpressed(joystick, button)
end

function love.joystickreleased(joystick, button)
    return JM:joystickreleased(joystick, button)
end

function love.joystickaxis(joystick, axis, value)
    return JM:joystickaxis(joystick, axis, value)
end

function love.joystickadded(joystick)
    return JM:joystickadded(joystick)
end

function love.joystickremoved(joystick)
    return JM:joystickremoved(joystick)
end

function love.gamepadpressed(joy, button)
    return JM:gamepadpressed(joy, button)
end

function love.gamepadreleased(joy, button)
    return JM:gamepadreleased(joy, button)
end

function love.gamepadaxis(joy, axis, value)
    return JM:gamepadaxis(joy, axis, value)
end

function love.resize(w, h)
    return JM:resize(w, h)
end

local km = 0
function love.update(dt)
    km = collectgarbage("count") / 1024.0
    return JM:update(dt)
end

function love.draw()
    JM:draw()

    do
        -- local font = JM.Font.current
        -- font:push()
        -- font:set_font_size(32)
        -- font:set_color(JM_Utils:get_rgba(1, 0, 0))
        -- font:print(succes and admob and "Loaded" or "Error", 10, 30)
        -- font:pop()

        lgx.setColor(0, 0, 0, 0.7)
        lgx.rectangle("fill", 0, 0, 80, 120)
        lgx.setColor(1, 1, 0, 1)
        lgx.print(string.format("Memory:\n\t%.2f Mb", km), 5, 10)
        lgx.print("FPS: " .. tostring(love.timer.getFPS()), 5, 50)
        local maj, min, rev, code = love.getVersion()
        lgx.print(string.format("Version:\n\t%d.%d.%d", maj, min, rev), 5, 75)

        -- local stats = love.graphics.getStats()
        -- local font = _G.JM_Font
        -- -- font:print(stats.texturememory / (10 ^ 6), 100, 96)
        -- font:print(stats.drawcalls, 200, 96 + 32)
        -- font:print(stats.canvasswitches, 200, 96 + 32 + 22)
    end
end
