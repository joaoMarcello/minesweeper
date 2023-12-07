local path = ...
local JM = _G.JM
local Utils = JM.Utils

do
    _G.SUBPIXEL = _G.SUBPIXEL or 3
    _G.CANVAS_FILTER = _G.CANVAS_FILTER or 'linear'
    _G.TILE = _G.TILE or 16
end

---@class GameState.Menu : JM.Scene
local State = JM.Scene:new {
    x = nil,
    y = nil,
    w = nil,
    h = nil,
    canvas_w = _G.SCREEN_WIDTH or 320,
    canvas_h = _G.SCREEN_HEIGHT or 180,
    tile = _G.TILE,
    subpixel = _G.SUBPIXEL or 3,
    canvas_filter = _G.CANVAS_FILTER or 'linear',
    bound_top = 0,
    bound_left = 0,
    bound_right = 1366,
    bound_bottom = 1366,
    cam_scale = 1,
}
--============================================================================
local data = {}

--============================================================================

function State:__get_data__()
    return data
end

---@type JM.Font.Font
local font_pix8,
---@type JM.Font.Font
font_pix5

---@type JM.Font.Font
local monogram
--============================================================================
local function load()
    font_pix8 = JM:get_font("pix8")

    local mult = 1
    monogram = monogram or JM.FontGenerator:new_by_ttf {
        dir = "/data/font/monogram-extended.ttf",
        name = 'monogram',
        dpi = 16 * mult,
        min_filter = 'linear',
        max_filter = 'nearest',
        character_space = 1,
        word_space = 5 * mult,
        -- save = true,
    }
    monogram:set_font_size(monogram.__ref_height / mult)
end

local function finish()

end

local function init(args)
    -- State:set_color(unpack(Utils:get_rgba()))
end

local function textinput(t)

end

local function keypressed(key)
    if key == 'o' then
        State.camera:toggle_grid()
        State.camera:toggle_world_bounds()
    end

    if key == 'q' then
        JM:flush()
    end
end

local function keyreleased(key)

end

local function mousepressed(x, y, button, istouch, presses)

end

local function mousereleased(x, y, button, istouch, presses)

end

local function mousemoved(x, y, dx, dy, istouch)

end

local function touchpressed(id, x, y, dx, dy, pressure)

end

local function touchreleased(id, x, y, dx, dy, pressure)

end

local function gamepadpressed(joystick, button)

end

local function gamepadreleased(joystick, button)

end

local function update(dt)

end

local lgx = love.graphics
local layer_main = {
    ---@param cam JM.Camera.Camera
    draw = function(self, cam)
        local font = JM:get_font() --JM.Font.current

        font:push()
        font:printf("um dois tres tesiando,\n chupa meu ovo", 16, 64)
        font:set_font_size(15)
        font:printf("um dois tres tesiando,\n chupa meu ovo", 128, 64)
        font:pop()
        -- font:printf(
        --     "Testando 1, 2, 3:dots: <font=color-hex, value=#a6fcdb> testes </color>ok <font=font-size, value=6> <color>ok \n ok<font=font-size, value=15></color>ok <font=font-size>asa Testando 1, 2, 3",
        --     32,
        --     32, "right", State.camera.viewport_w - 32)

        -- font:printx(
        --     "Testando_- 1, 2, ç ² 3:dots: <font=color-hex, value=#a6fcdb> <font=font-size, value=17>testes<font=font-size> </color>ok <color>ok\n ok</color> <effect=ghost>anta </effect> ok asa Testando 1, 2,\n \n 3asasasas",
        --     32,
        --     32, "right", State.camera.viewport_w - 32)

        -- font:print("astha :cpy: il \u{A9}\u{ae}\u{A7} pi\u{d1}ata @", 32, 16)



        -- font:printx(
        --     "Ow Testes 1, 2, 3 <font=font-size, value=22><effect=scream>Testando</effect><font=font-size>awastga não sabao \n 1, 2, <color>3</color>",
        --     16,
        --     32, "right", State.camera.viewport_w - 32)

        local r, g, b, a = Utils:hex_to_rgba_float("#a6fcdb")
        -- font_pix8:print(string.format("%.2f %.2f %.2f %s", r, g, b, tostring(a)), 16, 48)

        lgx.setColor(r, g, b, a)
        lgx.rectangle("fill", 180, 0, 32, 32)

        -- font_pix8:printf("Maoe Môe:dots: Até <color>agora</color> estou gostando\n do que me aconteceu\u{a9}", 0, 100,
        --     "right",
        --     State.camera.viewport_w)

        -- font:printx("This is monogram ² ~ ïç :bt_a: ï \u{a9} 1° \u{f1}", 0, 100)
        font:print(
            "<bold> <color-hex=0000ff>asç <a <color>ipt</bold> <color, 0, 0, 1>cç</effect> </color> ip<font=color-hex, value=#ffffff>tv</color>a<>",
            64, 130)

        font_pix8:print(
            "<<bold>abççá</bold> \n<bold>b</bold>:bt_a:<color, 0, 0, 1>:bt_x:</color> <color-hex=ffff00>iptva çapà", 64,
            160)

        -- font:print("ál Ω Ω ≈a", 0, 0)

        -- local Iter = require "jm-love2d-package.modules.font.font_iterator"
        -- local utf8 = require "utf8"
        -- local it = Iter:new("This as", font)

        -- local py = 32
        -- while it:has_next() do
        --     local g = it:next()
        --     g:draw(py, 10)
        --     py = py + 12
        -- end

        -- local t = font:separate_string("çc")
        -- py = 10
        -- for k, v in ipairs(t) do
        --     love.graphics.print(v, 0, py)
        --     font:print("çc", 20, py)
        --     py = py + 13
        -- end

        -- local codes = {}
        -- py = 0
        -- for p, c in utf8.codes("This is cç :bt_a il monogram \u{a9}îaa ã :bt_a: ï 1°") do
        --     codes[p] = utf8.char(c)
        --     lgx.print(utf8.char(c), 200, py)
        --     py = py + 12
        -- end
    end
}

local layers = {
    --
    layer_main,
    --
    --
}
--============================================================================
State:implements {
    load = load,
    init = init,
    finish = finish,
    textinput = textinput,
    keypressed = keypressed,
    keyreleased = keyreleased,
    mousepressed = mousepressed,
    mousereleased = mousereleased,
    mousemoved = mousemoved,
    touchpressed = touchpressed,
    touchreleased = touchreleased,
    gamepadpressed = gamepadpressed,
    gamepadreleased = gamepadreleased,
    update = update,
    layers = layers,
}

return State
