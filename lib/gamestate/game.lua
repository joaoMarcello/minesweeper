local path = ...
local JM = _G.JM_Package
local TileMap = JM.TileMap
local Utils = JM.Utils

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
    bomb = -1,
    flag = -2,
    press = -3,
    stand = -4,
    cover = -5,
    uncover = -6,
    explosion = -7,
}

local tile_to_state = {
    [1] = Cell.uncover,
    [2] = Cell.cover,
    [3] = Cell.press,
    [4] = Cell.flag,
    [5] = Cell.bomb,
    [6] = Cell.explosion,
}

local tile = _G.TILE

--============================================================================
---@class Gamestate.Game.Data
local data = {
    get_mouse_position = function(cam)
        return State:get_mouse_position(cam)
    end
}

local rand, floor = math.random, math.floor

local shuffle = function(t)
    local N = #t
    for i = N, 2, -1 do
        local j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function increment(x, y)
    if x < 0 or y < 0 then return false end
    if x > data.width - 1 or y > data.height - 1 then return false end

    local index = y * data.width + x
    if index >= data.width * data.height then return false end

    local cell = data.grid[index]
    if cell == Cell.bomb then return false end
    data.grid[index] = data.grid[index] or 0
    data.grid[index] = data.grid[index] + 1
    return true
end

local generic = function()

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
    data.tilemap = TileMap:new(generic, "/data/img/tilemap.png", 16)

    data.height = 8
    data.width = 8
    data.mines = 10
    data.grid = {}
    data.state = {}

    local t = {}
    local N = data.height * data.width
    for i = 0, N - 1 do
        t[i + 1] = i
    end
    shuffle(t)

    local mines_pos = {}
    for i = 0, data.mines - 1 do
        mines_pos[t[i + 1]] = true
    end

    for y = 0, data.height - 1 do
        for x = 0, data.width - 1 do
            local index = (y * data.width) + x
            data.grid[index] = data.grid[index] or 0


            data.state[index] = Cell.cover
            data.tilemap:insert_tile(tile * x, tile * y, 2)

            if mines_pos[index] then
                data.grid[index] = Cell.bomb
                increment(x - 1, y - 1)
                increment(x, y - 1)
                increment(x + 1, y - 1)
                increment(x - 1, y)
                increment(x + 1, y)
                increment(x - 1, y + 1)
                increment(x, y + 1)
                increment(x + 1, y + 1)
                -- data.tilemap:insert_tile(tile * x, tile * y, 5)
            end
        end
    end

    local mx, my = data.get_mouse_position()
    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)

    data.last_cell_x = data.cell_x
    data.last_cell_y = data.cell_y
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
    if istouch then return end

    if button == 1 then
        data.tilemap:insert_tile(data.cell_x * tile, data.cell_y * tile, 3)
    end
end

local function mousereleased(x, y, button, istouch, presses)
    if istouch then return end

    if button == 1 then
        data.tilemap:insert_tile(data.cell_x * tile, data.cell_y * tile, 4)
        data.tilemap:reset_spritebatch()
    end
end

local function mousemoved(x, y, dx, dy, istouch)
    local reset_spritebatch = false

    local mx, my = data.get_mouse_position()
    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)

    if data.cell_x ~= data.last_cell_x or data.cell_y ~= data.last_cell_y then
        local px = data.last_cell_x * tile
        local py = data.last_cell_y * tile

        local id = data.tilemap:get_id(px, py)

        if id == 3 then
            data.tilemap:insert_tile(px, py, 2)
            data.tilemap:insert_tile(data.cell_x * tile, data.cell_y * tile, 3)
            reset_spritebatch = true
        end
    end

    data.last_cell_x = data.cell_x
    data.last_cell_y = data.cell_y

    if reset_spritebatch then
        data.tilemap:reset_spritebatch()
    end
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

        data.tilemap:draw(cam)


        local px = 0
        local py = 0
        for y = 0, data.height - 1 do
            for x = 0, data.width - 1 do
                local index = (y * data.width) + x
                local cell = data.grid[index]

                if cell == Cell.bomb then
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.circle("fill", px + 8, py + 8, 4)
                else
                    love.graphics.setColor(1, 0, 0)
                    if cell and cell > 0 then
                        font:print(tostring(cell), tile * x + 4, tile * y + 4)
                    end
                end
                px = px + tile
            end
            py = py + tile
            px = 0
        end

        -- py = 10
        -- for i = 1, data.mines do
        --     font:print(tostring(data.t[i]), 150, py)
        --     py = py + 16
        -- end

        font:print(tostring(data.cell_x), 150, 16)
        font:print(tostring(data.cell_y), 150, 16 + 16)
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
