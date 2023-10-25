local path = ...
local JM = _G.JM_Package
local TileMap = JM.TileMap

do
    _G.SUBPIXEL = _G.SUBPIXEL or 3
    _G.CANVAS_FILTER = _G.CANVAS_FILTER or 'linear'
    _G.TILE = _G.TILE or 16
end

---@class Gamestate.Game : JM.Scene
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

---@enum Gamestate.Game.Modes
local Mode = {
    beginner = 1,
    intermediate = 2,
    expert = 3,
    custom = 4,
}

local Cell = {
    stand = 1,
    press = 2,
    flag = 3,
    bomb = 100,
}

--============================================================================
local data = {}

local rand = math.random

local shuffle = function(t)
    local N = #t
    for i = N, 2, -1 do
        local j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
end
--============================================================================

function State:__get_data__()
    return data
end

local function load()

end

local function finish()

end

local function init(args)
    love.mouse.setVisible(true)

    data.height = 8
    data.width = 8
    data.mines = 10
    data.grid = {}
    local t = {}
    local N = data.height * data.width
    for i = 0, N - 1 do
        t[i] = i
    end
    shuffle(t)

    data.t = t

    data.mines_pos = {}
    for i = 1, data.mines do
        data.mines_pos[t[i]] = true
    end

    for y = 0, data.height - 1 do
        for x = 0, data.width - 1 do
            local index = (y * data.width) + x
            if data.mines_pos[index] then
                data.grid[index] = Cell.bomb
            end
        end
    end
end

local function textinput(t)

end

local function keypressed(key)
    if key == 'o' then
        State.camera:toggle_grid()
        State.camera:toggle_world_bounds()
    end

    if key == 's' then
        State:init()
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

local layer_main = {
    ---@param cam JM.Camera.Camera
    draw = function(self, cam)
        local font = JM.Font.current

        local px   = 0
        local py   = 0
        for y = 0, data.height - 1 do
            for x = 0, data.width - 1 do
                local index = (y * data.width) + x

                if data.grid[index] == Cell.bomb then
                    love.graphics.setColor(0, 0, 0)
                else
                    love.graphics.setColor(1, 0, 0)
                end
                love.graphics.circle("fill", px + 8, py + 8, 4)
                px = px + TILE
            end
            py = py + TILE
            px = 0
        end

        py = 10
        for i = 1, 10 do
            font:print(tostring(data.t[i]), 132, py)
            py = py + 16
        end
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
