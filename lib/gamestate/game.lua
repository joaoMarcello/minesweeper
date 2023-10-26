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
    suspicious = -8,
}

local tile_to_state = {
    [1] = Cell.uncover,
    [2] = Cell.cover,
    [3] = Cell.press,
    [4] = Cell.flag,
    [5] = Cell.bomb,
    [6] = Cell.explosion,
    [7] = Cell.uncover,
    [8] = Cell.uncover,
    [9] = Cell.uncover,
    [10] = Cell.uncover,
    [11] = Cell.uncover,
    [12] = Cell.uncover,
    [13] = Cell.uncover,
    [14] = Cell.uncover,
    [15] = Cell.suspicious,
}

local state_to_tile = {
    [Cell.uncover] = 1,
    [Cell.cover] = 2,
    [Cell.press] = 3,
    [Cell.flag] = 4,
    [Cell.bomb] = 5,
    [Cell.explosion] = 6,
    [Cell.suspicious] = 15,
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
    -- data.state[index] = Cell.uncover
    return true
end

local function position_is_inside_board(x, y)
    return x > 0 and x <= data.width * tile and y > 0 and y <= data.height * tile
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

    -- data.tilemap:insert_tile(16, 16, state_to_tile[Cell.uncover])
    -- data.tilemap:insert_tile(16, 32, state_to_tile[Cell.uncover])
    -- data.tilemap:insert_tile(32, 32, state_to_tile[Cell.uncover])
    -- data.tilemap:insert_tile(16, 16, state_to_tile[Cell.uncover])
    -- data.tilemap:insert_tile(16, 16, state_to_tile[Cell.uncover])
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

    if key == 'u' then
        data:reveal_game()
    end
end

local function keyreleased(key)

end

---@param self Gamestate.Game.Data
data.reveal_game = function(self)
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local px = x * tile
            local py = y * tile
            local index = y * self.width + x
            local value = self.grid[index]

            if value < 0 then
                if value ~= Cell.explosion then
                    self.tilemap:insert_tile(px, py, state_to_tile[Cell.bomb])
                end
            else
                self:uncover_cells(x, y)
            end
        end
    end
end


---@param self Gamestate.Game.Data
data.uncover_cells = function(self, cellx, celly)
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = data.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = celly * data.width + cellx
    local value = self.grid[index]

    if data.state[index] == Cell.uncover
    then
        return false
    end


    if value == 0 then
        data.state[index] = Cell.uncover

        if state ~= Cell.flag then
            data.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        end

        self:uncover_cells(cellx - 1, celly - 1)
        self:uncover_cells(cellx, celly - 1)
        self:uncover_cells(cellx + 1, celly - 1)
        self:uncover_cells(cellx - 1, celly)
        self:uncover_cells(cellx + 1, celly)
        self:uncover_cells(cellx - 1, celly + 1)
        self:uncover_cells(cellx, celly + 1)
        self:uncover_cells(cellx + 1, celly + 1)
        ---
    elseif value > 0 then
        data.state[index] = Cell.uncover
        data.tilemap:insert_tile(px, py, 6 + value)
    end


    return true
end

local function mousepressed(x, y, button, istouch, presses)
    if istouch then return end

    if not position_is_inside_board(x, y) then return end

    if (button == 1 and love.mouse.isDown(2))
        or (button == 2 and love.mouse.isDown(1))
    then
        ---
    elseif button == 1 or button == 2 then
        local px = data.cell_x * tile
        local py = data.cell_y * tile
        local id = data.tilemap:get_id(px, py)

        if tile_to_state[id] == Cell.cover then
            data.tilemap:insert_tile(px, py, state_to_tile[Cell.press])
            data.tilemap:reset_spritebatch()
        end
    end
end

local function mousereleased(x, y, button, istouch, presses)
    if istouch then return end

    local mx, my = data.get_mouse_position()
    local is_inside_board = position_is_inside_board(mx, my)

    local px = data.cell_x * tile
    local py = data.cell_y * tile
    local id = data.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = data.cell_y * data.width + data.cell_x

    if button == 2 or button == 1 then
        if is_inside_board and state ~= Cell.uncover then
            if button == 2 then
                if state == Cell.flag then
                    data.tilemap:insert_tile(px, py, state_to_tile[Cell.suspicious])
                    data.state[index] = Cell.cover
                    ---
                elseif state == Cell.suspicious then
                    data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                    data.state[index] = Cell.cover
                    ---
                elseif state == Cell.press then
                    data.tilemap:insert_tile(px, py, state_to_tile[Cell.flag])
                    ---
                end

                data.tilemap:reset_spritebatch()
                --------------
            else
                -- Button == 1
                if data.grid[index] == Cell.bomb then
                    data.grid[index] = Cell.explosion

                    data.tilemap:insert_tile(px, py,
                        state_to_tile[Cell.explosion])

                    data:reveal_game()
                else
                    data:uncover_cells(data.cell_x, data.cell_y)
                end

                data.tilemap:reset_spritebatch()
            end
            --
        else
            if state == Cell.press then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                data.tilemap:reset_spritebatch()
            end
        end
    end
end

local function mousemoved(x, y, dx, dy, istouch)
    -- if not position_is_inside_board(x, y) then return end

    local reset_spritebatch = false

    local mx, my = data.get_mouse_position()
    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)

    local is_inside_board = position_is_inside_board(mx, my)

    if not is_inside_board then
        local px = data.last_cell_x * tile
        local py = data.last_cell_y * tile
        local id = data.tilemap:get_id(px, py)
        local state = tile_to_state[id]

        if state == Cell.press then
            data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
            reset_spritebatch = true

            -- data.last_cell_x = data.cell_x
            -- data.last_cell_y = data.cell_y
        end
    end

    if (data.cell_x ~= data.last_cell_x or data.cell_y ~= data.last_cell_y)
        and is_inside_board
    then
        local px = data.last_cell_x * tile
        local py = data.last_cell_y * tile

        local id = data.tilemap:get_id(px, py)
        local last_state = tile_to_state[id]

        if (last_state == Cell.press)
            or (love.mouse.isDown(1) or love.mouse.isDown(2))
        then
            if last_state == Cell.press then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                reset_spritebatch = true
            end

            local cur_id = data.tilemap:get_id(data.cell_x * tile, data.cell_y * tile)
            local cur_state = tile_to_state[cur_id]

            if cur_state ~= Cell.flag and cur_state ~= Cell.uncover
            then
                data.tilemap:insert_tile(data.cell_x * tile, data.cell_y * tile, state_to_tile[Cell.press])
                reset_spritebatch = true
            end
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
                    love.graphics.setColor(0, 0, 0, 0.12)
                    love.graphics.circle("fill", px + 8, py + 8, 4)
                else
                    if cell and cell > 0 then
                        font:push()
                        font:set_color(Utils:get_rgba(0, 0, 0, 0.12))
                        font:print(tostring(cell), tile * x + 4, tile * y + 4)
                        font:pop()
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

        local mx, my = data.get_mouse_position()
        font:print(position_is_inside_board(mx, my) and "True" or "False", 150, 66)
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
