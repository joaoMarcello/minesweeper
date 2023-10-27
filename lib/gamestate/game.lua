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

State:add_camera {
    name = "cam2",
    border_color = Utils:get_rgba(),
}
local cam2 = State:get_camera("cam2")
cam2:set_viewport(200, nil, State.screen_w / 2, State.screen_h)

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
    wrong = -9,
    susp_pressed = -10,
}

local tile_to_state = {
    [1] = Cell.uncover,
    [2] = Cell.cover,
    [3] = Cell.press,
    [4] = Cell.flag,
    [5] = Cell.bomb,
    [6] = Cell.explosion,
    -- Revealed numbers
    [7] = Cell.uncover,
    [8] = Cell.uncover,
    [9] = Cell.uncover,
    [10] = Cell.uncover,
    [11] = Cell.uncover,
    [12] = Cell.uncover,
    [13] = Cell.uncover,
    [14] = Cell.uncover,
    ---
    [15] = Cell.suspicious,
    [16] = Cell.wrong,
    [17] = Cell.susp_pressed,
    -- pressed numbers
    [18] = Cell.uncover,
    [19] = Cell.uncover,
    [20] = Cell.uncover,
    [21] = Cell.uncover,
    [22] = Cell.uncover,
    [23] = Cell.uncover,
    [24] = Cell.uncover,
    [25] = Cell.uncover,
}

local state_to_tile = {
    [Cell.uncover] = 1,
    [Cell.cover] = 2,
    [Cell.press] = 3,
    [Cell.flag] = 4,
    [Cell.bomb] = 5,
    [Cell.explosion] = 6,
    [Cell.suspicious] = 15,
    [Cell.wrong] = 16,
    [Cell.susp_pressed] = 17,
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
local mouse = love.mouse

local shuffle = function(t, n)
    local N = n or #t
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
    -- data.grid[index] = data.grid[index] or 0
    data.grid[index] = data.grid[index] + 1
    return true
end

local function position_is_inside_board(x, y)
    return x > 0 and x <= data.width * tile and y > 0 and y <= data.height * tile and
        State.camera:point_is_on_screen(x, y)
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

---@param self Gamestate.Game.Data
data.build_board = function(self, exception)
    local t = {}
    local N = self.height * self.width
    for i = 0, N - 1 do
        t[i + 1] = i
    end
    -- math.randomseed(3)
    shuffle(t, N)

    local mines_pos = {}
    local i = 0
    local j = 1
    while i < self.mines do
        local cell = t[j]
        if not cell then break end

        if cell ~= exception then
            -- mines_pos[t[i + 1]] = true
            mines_pos[cell] = true
            i = i + 1
        end
        j = j + 1
    end

    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local index = (y * self.width) + x
            local px = tile * x
            local py = tile * y
            -- local id =
            local state = tile_to_state[self.tilemap:get_id(px, py)]

            if state ~= Cell.flag and state ~= Cell.suspicious then
                self.tilemap:insert_tile(tile * x, tile * y, state_to_tile[Cell.cover])
            end

            if mines_pos[index] then
                self.grid[index] = Cell.bomb
                increment(x - 1, y - 1)
                increment(x, y - 1)
                increment(x + 1, y - 1)
                increment(x - 1, y)
                increment(x + 1, y)
                increment(x - 1, y + 1)
                increment(x, y + 1)
                increment(x + 1, y + 1)
            end
        end
    end
end

local meta_grid = { __index = function() return 0 end }
local meta_state = { __index = function() return Cell.cover end }

local function init(args)
    data.tilemap = TileMap:new(generic, "data/img/tilemap.png", 16)

    data.height = 8 --+ 4
    data.width = 8  --+ 4
    data.mines = 10 --28
    data.grid = setmetatable({}, meta_grid)
    data.state = setmetatable({}, meta_state)
    data.first_click = true
    data.continue = 2
    data.time_click = 0.0
    data.time_release = 0.0
    data.pressing = false
    data.cam2 = State:get_camera("cam2")

    local cam = State.camera
    cam:set_position(0, 0)
    -- cam.scale = 1.23
    cam:set_bounds(
        -(data.width * tile) / 2,
        Utils:clamp(data.width * tile * 1.5, State.screen_w, math.huge),
        -(data.width * tile) / 2,
        State.screen_h + (data.height * tile) / 2)

    -- filling tilemap with cover cells
    for y = 0, data.height - 1 do
        for x = 0, data.width - 1 do
            data.tilemap:insert_tile(x * tile, y * tile, state_to_tile[Cell.cover])
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

    if key == 'i' then
        State:init()
    end

    if key == 'r' then
        data:revive()
    end

    if key == 'u' then
        data.continue = 0
        data:reveal_game()
    end
end

local function keyreleased(key)

end

---@param self Gamestate.Game.Data
data.reveal_game = function(self)
    local r = self.continue > 0
    local skip_flags = false
    local skip_mines = r

    local xpx, xpy, xindex

    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local px = x * tile
            local py = y * tile
            local index = y * self.width + x
            local value = self.grid[index]
            local id = self.tilemap:get_id(px, py)

            -- cell is a bomb
            if value < 0 then
                if value ~= Cell.explosion
                    and tile_to_state[id] ~= Cell.flag
                    and not skip_mines
                then
                    self.tilemap:insert_tile(px, py, state_to_tile[Cell.bomb])
                end
                xpx = px
                xpy = py
                xindex = index
                ---
            else
                if tile_to_state[id] == Cell.flag and not skip_flags then
                    self.tilemap:insert_tile(px, py, state_to_tile[Cell.wrong])
                end
            end
        end
    end
    return xpx, xpy, xindex
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

    if self.state[index] == Cell.uncover
    then
        return false
    end

    if value == 0 then
        self.state[index] = Cell.uncover

        if state ~= Cell.flag then
            data.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        end
        -- data:reveal_cell(cellx, celly)

        self:uncover_cells(cellx - 1, celly - 1)
        self:uncover_cells(cellx, celly - 1)
        self:uncover_cells(cellx + 1, celly - 1)
        self:uncover_cells(cellx - 1, celly)
        self:uncover_cells(cellx + 1, celly)
        self:uncover_cells(cellx - 1, celly + 1)
        self:uncover_cells(cellx, celly + 1)
        self:uncover_cells(cellx + 1, celly + 1)
        ---
    elseif value > 0 and state ~= Cell.flag then
        data.state[index] = Cell.uncover
        data.tilemap:insert_tile(px, py, 6 + value)
    end

    return true
end

---@param self Gamestate.Game.Data
data.press_cell = function(self, cellx, celly, press_uncover)
    -- press_uncover = true
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = celly * self.width + cellx
    local value = self.grid[index]

    if state == Cell.cover and state ~= Cell.press then
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.press])
        ---
    elseif state == Cell.suspicious and state ~= Cell.susp_pressed then
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.susp_pressed])
        ---
    elseif state == Cell.uncover and press_uncover then
        if value > 0 then
            self.tilemap:insert_tile(px, py, 17 + value)
        elseif value == 0 then
            self.tilemap:insert_tile(px, py, state_to_tile[Cell.press])
        end
    else
        return false
    end
    return true
end

---@param self Gamestate.Game.Data
data.unpress_cell = function(self, cellx, celly, unpress_uncover)
    -- unpress_uncover
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = celly * self.width + cellx
    local value = self.grid[index]

    if state == Cell.press and state ~= Cell.cover
        and self.state[index] ~= Cell.uncover
    then
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
        ---
    elseif state == Cell.susp_pressed and state ~= Cell.suspicious then
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.suspicious])
        ---
    elseif self.state[index] == Cell.uncover and unpress_uncover then
        if value > 0 then
            self.tilemap:insert_tile(px, py, 6 + value)
        elseif value == 0 then
            self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        end
    else
        return false
    end
    return true
end

data.revive = function(self)
    if data.continue <= 0 then return false end

    for y = 0, self.height - 1 do
        for x = 0, self.width do
            local px = x * tile
            local py = y * tile
            local id = self.tilemap:get_id(px, py)
            local state = tile_to_state[id]

            if state == Cell.wrong then
                self:reveal_cell(x, y)
            elseif state == Cell.explosion then
                self.tilemap:insert_tile(px, py, state_to_tile[Cell.flag])
            end
        end
    end

    data.continue = data.continue - 1
    return true
end

---@param self Gamestate.Game.Data
data.press_neighbor = function(self, cellx, celly)
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local r = self:press_cell(cellx, celly, true)

    r = self:press_cell(cellx - 1, celly - 1, true) or r
    r = self:press_cell(cellx, celly - 1, true) or r
    r = self:press_cell(cellx + 1, celly - 1, true) or r
    r = self:press_cell(cellx - 1, celly, true) or r
    r = self:press_cell(cellx + 1, celly, true) or r
    r = self:press_cell(cellx - 1, celly + 1, true) or r
    r = self:press_cell(cellx, celly + 1, true) or r
    r = self:press_cell(cellx + 1, celly + 1, true) or r

    return r
end

---@param self Gamestate.Game.Data
data.unpress_neighbor = function(self, cellx, celly)
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local r = self:unpress_cell(cellx, celly, true)

    r = self:unpress_cell(cellx - 1, celly - 1, true) or r
    r = self:unpress_cell(cellx, celly - 1, true) or r
    r = self:unpress_cell(cellx + 1, celly - 1, true) or r
    r = self:unpress_cell(cellx - 1, celly, true) or r
    r = self:unpress_cell(cellx + 1, celly, true) or r
    r = self:unpress_cell(cellx - 1, celly + 1, true) or r
    r = self:unpress_cell(cellx, celly + 1, true) or r
    r = self:unpress_cell(cellx + 1, celly + 1, true) or r

    return r
end

local function is_flag(cellx, celly)
    if cellx < 0 or celly < 0 then return 0 end
    if cellx > data.width - 1 or celly > data.height - 1 then return 0 end

    local px = cellx * tile
    local py = celly * tile
    local id = data.tilemap:get_id(px, py)
    local state = id and tile_to_state[id]
    -- local index = celly * data.width + cellx

    return (state == Cell.flag) and 1 or 0
    -- return (data.grid[index] < 0 or state == Cell.flag) and 1 or 0
end

---@param self Gamestate.Game.Data
data.count_neighbor_flags = function(self, cellx, celly)
    if cellx < 0 or celly < 0 then return 0 end
    if cellx > self.width - 1 or celly > self.height - 1 then return 0 end

    local r = is_flag(cellx - 1, celly - 1)
    r = r + is_flag(cellx, celly - 1)
    r = r + is_flag(cellx + 1, celly - 1)
    r = r + is_flag(cellx - 1, celly)
    r = r + is_flag(cellx + 1, celly)
    r = r + is_flag(cellx - 1, celly + 1)
    r = r + is_flag(cellx, celly + 1)
    r = r + is_flag(cellx + 1, celly + 1)

    return r
end

--- returns -1 if cell is bomb
data.reveal_cell = function(self, cellx, celly, show_explosion)
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = id and tile_to_state[id]
    local index = celly * data.width + cellx
    local value = self.grid[index]

    if state == Cell.uncover or state == Cell.flag then return false end

    if value > 0 then
        self.tilemap:insert_tile(px, py, value + 6)
        data.state[index] = Cell.uncover
    elseif value == 0 then
        self:uncover_cells(cellx, celly)
        data.state[index] = Cell.uncover
        data.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
    elseif value < 0 then -- cell is bomb
        if show_explosion then
            data.tilemap:insert_tile(px, py, state_to_tile[Cell.explosion])
        end
        return -1
    else
        return false
    end
    return true
end

---@param self Gamestate.Game.Data
data.verify_chording = function(self, cellx, celly)
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = celly * data.width + cellx
    local value = self.grid[index]

    if value > 0 and state ~= Cell.cover then
        local count = data:count_neighbor_flags(cellx, celly)
        -- data.count_mines = count
        local r1, r2, r3, r4, r5, r6, r7, r8

        if count == value then
            r1 = self:reveal_cell(cellx - 1, celly - 1, true)
            r2 = self:reveal_cell(cellx, celly - 1, true)
            r3 = self:reveal_cell(cellx + 1, celly - 1, true)
            r4 = self:reveal_cell(cellx - 1, celly, true)
            r5 = self:reveal_cell(cellx + 1, celly, true)
            r6 = self:reveal_cell(cellx - 1, celly + 1, true)
            r7 = self:reveal_cell(cellx, celly + 1, true)
            r8 = self:reveal_cell(cellx + 1, celly + 1, true)

            if r1 == -1 or r2 == -1 or r3 == -1 or r4 == -1 or r5 == -1 or r6 == -1 or r7 == -1 or r8 == -1 then
                self:reveal_game()
                self.tilemap:reset_spritebatch()
            end
        end
    end
end

local function mousepressed(x, y, button, istouch, presses)
    if istouch then return end

    local mx, my = data.get_mouse_position()
    local is_inside_board = position_is_inside_board(mx, my)

    if not is_inside_board or button > 2 then return end

    data.pressing = true

    local px = data.cell_x * tile
    local py = data.cell_y * tile
    local id = data.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = data.cell_y * data.width + data.cell_x
    local reset_spritebatch = false
    local allow_click = data.time_click < 0.5
        and data.time_release <= 0.0
        and data.pressing

    if (button == 1 and mouse.isDown(2))
        or (button == 2 and mouse.isDown(1))
        or (data.state[index] == Cell.uncover and button == 2 and state ~= Cell.flag)
    then
        data.chording = true
        data:press_neighbor(data.cell_x, data.cell_y)
        ---
    elseif button == 1 or button == 2 then
        if data:press_cell(data.cell_x, data.cell_y) then
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
    local reset_spritebatch = false
    local allow_click = data.time_click < 0.5
        and data.time_release <= 0.0
        and data.pressing

    if data.first_click and is_inside_board and button == 1
        and state ~= Cell.flag
        and allow_click
        and not data.chording
    then
        data.first_click = false
        data:build_board(data.cell_y * data.width + data.cell_x)
        reset_spritebatch = true
    end

    if data.chording then
        data:unpress_neighbor(data.cell_x, data.cell_y)

        if not data.first_click then
            data:verify_chording(data.cell_x, data.cell_y)
        end
        data.chording = false
        ---
    elseif is_inside_board and state ~= Cell.uncover and allow_click then
        if button == 2 then
            if state == Cell.flag then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.suspicious])
                data.state[index] = Cell.cover
                ---
            elseif state == Cell.suspicious then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                data.state[index] = Cell.cover
                ---
            elseif state == Cell.press or state == Cell.cover then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.flag])
                ---
            elseif state == Cell.susp_pressed then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                ---
            end
            reset_spritebatch = true

            ---
        elseif button == 1 then
            if data.grid[index] < 0 and state ~= Cell.flag then
                data:reveal_game()

                data.tilemap:insert_tile(px, py, state_to_tile[Cell.explosion])
                ---
            elseif state ~= Cell.flag then
                -- data.state[index] = Cell.uncover
                data:unpress_cell(data.cell_x, data.cell_y)
                data:uncover_cells(data.cell_x, data.cell_y)
            end

            reset_spritebatch = true
        end

        data.time_release = 0.06

        --
    else
        ---
        reset_spritebatch = data:unpress_cell(data.cell_x, data.cell_y)
        reset_spritebatch = data:unpress_cell(data.last_cell_x, data.last_cell_y) or reset_spritebatch

        -- if data.chore then
        --     data.chore = false
        -- end
    end

    if data.pressing and button <= 2 then
        data.pressing = false
        data.time_click = 0.0
    end

    if reset_spritebatch then
        data.tilemap:reset_spritebatch()
    end
end

local function mousemoved(x, y, dx, dy, istouch)
    if istouch then return end

    local reset_spritebatch = false

    local mx, my = data.get_mouse_position()
    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)

    local is_inside_board = position_is_inside_board(mx, my)

    data.last_state = tile_to_state[data.tilemap:get_id(data.last_cell_x * tile, data.last_cell_y * tile)]

    if data.chording then
        -- if data.cell_x ~= data.last_cell_x
        --     and data.cell_y ~= data.last_cell_y
        -- then
        if not is_inside_board then
            data:unpress_neighbor(data.last_cell_x, data.last_cell_y)
            data:unpress_neighbor(data.cell_x, data.cell_y)
            reset_spritebatch = true
            -- data.chore = false
            -- data.pressing = false
        else
            data:unpress_neighbor(data.last_cell_x, data.last_cell_y)
            data:press_neighbor(data.cell_x, data.cell_y)
            reset_spritebatch = true
        end
    elseif not is_inside_board then
        reset_spritebatch = data:unpress_cell(data.last_cell_x, data.last_cell_y) or reset_spritebatch

        if data.chording then
            -- data.chore = false
        end
        ---
    elseif data.pressing then
        local px = data.last_cell_x * tile
        local py = data.last_cell_y * tile

        local id = data.tilemap:get_id(px, py)
        local last_state = tile_to_state[id]

        if (last_state == Cell.press or last_state == Cell.susp_pressed)
            or (mouse.isDown(1) or mouse.isDown(2))
        then
            reset_spritebatch = data:unpress_cell(data.last_cell_x, data.last_cell_y) or reset_spritebatch

            do
                reset_spritebatch = data:press_cell(data.cell_x, data.cell_y) or reset_spritebatch
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
    if data.pressing then
        data.time_click = data.time_click + dt
    end

    if data.time_release > 0.0
        and not mouse.isDown(1)
        and not mouse.isDown(2)
    then
        data.time_release = Utils:clamp(data.time_release - dt, 0.0, 100.0)
    end

    local cam = State.camera
    local speed = 32
    local controller = JM.ControllerManager.P1

    if controller:pressing(controller.Button.dpad_right) then
        cam:move(speed * dt)
    elseif controller:pressing(controller.Button.dpad_left) then
        cam:move(-speed * dt)
    end

    if controller:pressing(controller.Button.dpad_down) then
        cam:move(0, speed * dt)
    elseif controller:pressing(controller.Button.dpad_up) then
        cam:move(0, -speed * dt)
    end
end

local layer_main = {
    ---@param cam JM.Camera.Camera
    draw = function(self, cam)
        if cam == data.cam2 then return end

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

        -- font:print(tostring(data.cell_x), 200, 16)
        -- font:print(tostring(data.cell_y), 200, 16 + 16)
        -- font:print(tostring(data.cell_y * data.width + data.cell_x), 200, 16 + 16 + 16)

        -- font:print(data.pressing and "Pressing" or "not press", 200, 150)
        -- font:print(tostring(data.time_click), 150, 150 + 16)

        -- font:print(data.chording and "Chore" or "not chore", 20, 150)
        -- local mx, my = data.get_mouse_position()
        -- font:print(position_is_inside_board(mx, my) and "True" or "False", 200, 66)


        -- font:print(tostring(data.count_mines), 20, 160)
    end
}

local layer_gui = {
    ---@param cam JM.Camera.Camera
    draw = function(self, cam)
        if cam == State.camera then return end
        love.graphics.setColor(0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, 100, 32)
        local font = JM.Font.current
        font:print("Continue " .. tostring(data.continue), 20, 90)
    end
}

local layers = {
    --
    layer_main,
    layer_gui,
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
