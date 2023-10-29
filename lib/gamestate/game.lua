local path = ...
local JM = _G.JM_Package
local TileMap = JM.TileMap
local Utils = JM.Utils
local TileSet = JM.TileSet

do
    _G.SUBPIXEL = _G.SUBPIXEL or 3
    _G.CANVAS_FILTER = _G.CANVAS_FILTER or 'linear'
    _G.TILE = _G.TILE or 16
end


---@class Gamestate.Game : JM.Scene
local State = JM.Scene:new {
    x = nil, --100,
    y = nil, --75,
    w = nil, --love.graphics.getWidth() - 200,
    h = nil, --love.graphics.getHeight() - 60 - 75,
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
    show_border = true,
}

State:add_camera {
    name = "cam2",
    border_color = Utils:get_rgba(),
}
local cam2 = State:get_camera("cam2")
cam2:set_viewport(200, nil, State.screen_w / 2, State.screen_h)

---@enum Gamestate.Game.Modes
local GameMode = {
    beginner = 1,
    intermediate = 2,
    expert = 3,
    custom = 4,
}

local GameStates = {
    victory = 1,
    dead = 2,
    playing = 3,
}

---@enum GameState.Game.ClickState
local ClickState = {
    reveal = 1,
    flag = 2,
    suspicious = 3,
    chording = 4,
}

local Cell = {
    bomb = -1,
    flag = -2,
    press = -3,
    cover = -5,
    uncover = -6,
    explosion = -7,
    wrong = -9,
}

local tile_to_state = {
    [1] = Cell.uncover,
    [2] = Cell.cover,
    [3] = Cell.press,
    [4] = Cell.flag,
    [5] = Cell.bomb,
    [6] = Cell.explosion,
    [7] = Cell.wrong,
}

local state_to_tile = {
    [Cell.uncover] = 1,
    [Cell.cover] = 2,
    [Cell.press] = 3,
    [Cell.flag] = 4,
    [Cell.bomb] = 5,
    [Cell.explosion] = 6,
    [Cell.wrong] = 7,
}

local tile = _G.TILE

--============================================================================
---@class Gamestate.Game.Data
local data = {}

local rand, floor = math.random, math.floor
local mouse = love.mouse
local lgx = love.graphics

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

            if state ~= Cell.flag then
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

local MIN_SCALE_TO_LOW_RES = 0.3

local function init(args)
    data.tilemap = TileMap:new(generic, "data/img/tilemap.png", 16)
    data.number_tilemap = TileMap:new(generic, "data/img/number_tilemap.png", 16)

    data.full_tileset = data.tilemap.tile_set
    data.low_tileset = TileSet:new("data/img/tilemap-low.png", 16)

    data.height = 8 --+ 4
    data.width = 8  --+ 4
    data.mines = 10 --Utils:round(16 * 16 * 0.2)
    data.grid = setmetatable({}, meta_grid)
    data.state = setmetatable({}, meta_state)
    data.first_click = true
    data.continue = 2
    data.time_click = 0.0
    data.time_release = 0.0
    data.pressing = false
    data.gamestate = GameStates.playing

    data.cam2 = State:get_camera("cam2")

    State:set_color(0.5, 0.5, 0.5, 1)

    local cam = State.camera
    cam:set_position(0, 0)
    cam.scale = 1
    cam.min_zoom = 0.015
    cam.max_zoom = 2
    -- cam.scale = 1.23
    -- cam:set_bounds(
    --     -(data.width * tile) / 2,
    --     Utils:clamp(data.width * tile * 1.5, State.screen_w, math.huge),
    --     -(data.width * tile) / 2,
    -- State.screen_h + (data.height * tile) / 2)
    local off = Utils:round(data.width / 8 * 15)
    cam:set_bounds(-tile * off,
        data.width * tile + tile * off,
        -tile * off,
        data.height * tile + tile * off)

    -- cam:set_bounds(-math.huge, math.huge, -math.huge, math.huge)

    -- filling tilemap with cover cells
    for y = 0, data.height - 1 do
        for x = 0, data.width - 1 do
            data.tilemap:insert_tile(x * tile, y * tile, state_to_tile[Cell.cover])
        end
    end

    local mx, my = State:get_mouse_position() --data.get_mouse_position()
    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)

    data.last_cell_x = data.cell_x
    data.last_cell_y = data.cell_y

    data.uncover_cells_protected = function()
        data:uncover_cells(data.cell_x, data.cell_y)
    end
end

function data:verify_victory()
    local w, h = self.width, self.height

    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local index = y * w + x
            local value = self.grid[index]

            if value >= 0 and self.state[index] == Cell.cover then
                return false
            end
        end
    end
    return true
end

local function textinput(t)

end

local function keypressed(key)
    if key == 'o' then
        State.camera:toggle_grid()
        State.camera:toggle_world_bounds()
        State.camera:toggle_debug()
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
    local has_continue = self.continue > 0
    -- local skip_flags = false
    local skip_mines = has_continue

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
                ---
            else
                local is_neighbor = math.abs(self.cell_x - x) <= 1 and math.abs(self.cell_y - y) <= 1

                if tile_to_state[id] == Cell.flag
                    and ((self.chording and is_neighbor) or not has_continue)
                then
                    self.tilemap:insert_tile(px, py, state_to_tile[Cell.wrong])
                end
            end
        end
    end
end

-- local cx, cy
-- local function foo()
--     data:uncover_cells(cx, cy)
-- end

---@param self Gamestate.Game.Data
data.uncover_cells = function(self, cellx, celly)
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = celly * self.width + cellx
    local value = self.grid[index]

    if self.state[index] == Cell.uncover
    then
        return false
    end

    data.last_index_uncover = index

    if value == 0 then
        self.state[index] = Cell.uncover

        if state ~= Cell.flag then
            self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
            self.number_tilemap:insert_tile(px, py)
        end
        -- data:reveal_cell(cellx, celly)

        -- self:uncover_cells(cellx - 1, celly - 1)
        -- self:uncover_cells(cellx, celly - 1)
        -- self:uncover_cells(cellx + 1, celly - 1)
        -- self:uncover_cells(cellx - 1, celly)
        -- self:uncover_cells(cellx + 1, celly)
        -- self:uncover_cells(cellx - 1, celly + 1)
        -- self:uncover_cells(cellx, celly + 1)
        -- self:uncover_cells(cellx + 1, celly + 1)

        self:uncover_cells(cellx - 1, celly)
        self:uncover_cells(cellx - 1, celly - 1)
        self:uncover_cells(cellx, celly - 1)
        self:uncover_cells(cellx + 1, celly)
        self:uncover_cells(cellx - 1, celly + 1)
        self:uncover_cells(cellx, celly + 1)
        self:uncover_cells(cellx + 1, celly - 1)
        self:uncover_cells(cellx + 1, celly + 1)

        ---
    elseif value > 0 and state ~= Cell.flag then
        self.state[index] = Cell.uncover

        self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        self.number_tilemap:insert_tile(px, py, value)
    end

    return true
end

---@param self Gamestate.Game.Data
local function neighbor_is_uncover(self, cellx, celly, fill)
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local index = celly * self.width + cellx
    local r = self.state[index] == Cell.uncover
    if r and fill then
        local px = cellx * tile
        local py = celly * tile
        self.tilemap:insert_tile(px, py, fill)
    end
    return r
end

---@param self Gamestate.Game.Data
data.press_cell = function(self, cellx, celly, press_uncover)
    press_uncover = false
    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = celly * self.width + cellx

    if self.state[index] == Cell.cover
        and state ~= Cell.flag
        and state ~= Cell.explosion
    then
        neighbor_is_uncover(self, cellx, celly + 1, 8)

        if neighbor_is_uncover(self, cellx + 1, celly) then
            self.tilemap:insert_tile(px, py, 9)
        else
            self.tilemap:insert_tile(px, py, state_to_tile[Cell.press])
        end

        if self.number_tilemap:get_id(px, py) == 9 then
            self.number_tilemap:insert_tile(px, py, 10)
        end
        ---
    elseif self.state[index] == Cell.uncover and press_uncover then
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.press])
    else
        return false
    end
    return true
end

---@param self Gamestate.Game.Data
data.unpress_cell = function(self, cellx, celly, unpress_uncover)
    unpress_uncover = false

    if cellx < 0 or celly < 0 then return false end
    if cellx > self.width - 1 or celly > self.height - 1 then return false end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = celly * self.width + cellx
    -- local value = self.grid[index]

    if self.state[index] == Cell.cover
        and state ~= Cell.flag
        and state ~= Cell.explosion
    then
        neighbor_is_uncover(self, cellx, celly + 1, 1)
        -- neighbor_is_uncover(self, cellx + 1, celly, 1)

        self.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])

        if self.number_tilemap:get_id(px, py) == 10 then
            self.number_tilemap:insert_tile(px, py, 9)
        end
        ---
    elseif self.state[index] == Cell.uncover and unpress_uncover then
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
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

    return (state == Cell.flag) and 1 or 0
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
    local index = celly * self.width + cellx
    local value = self.grid[index]

    if state == Cell.uncover or state == Cell.flag then return false end

    if value > 0 then
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        self.number_tilemap:insert_tile(px, py, value)
        self.state[index] = Cell.uncover
        ---
    elseif value == 0 then
        local func = function()
            self:uncover_cells(cellx, celly)
        end
        pcall(func)
        -- self:uncover_cells(cellx, celly)

        self.state[index] = Cell.uncover
        self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        self.number_tilemap:insert_tile(px, py)
    elseif value < 0 then -- cell is bomb
        if show_explosion then
            self.tilemap:insert_tile(px, py, state_to_tile[Cell.explosion])
            self.number_tilemap:insert_tile(px, py)
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
    local index = celly * self.width + cellx
    local value = self.grid[index]

    if value > 0 and state ~= Cell.cover then
        local count = self:count_neighbor_flags(cellx, celly)
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

    local mx, my = State:get_mouse_position() --data.get_mouse_position()
    local is_inside_board = position_is_inside_board(mx, my)

    if not is_inside_board or button > 2 then return end

    data.pressing = true

    local px = data.cell_x * tile
    local py = data.cell_y * tile
    local id = data.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = data.cell_y * data.width + data.cell_x

    if (button == 1 and mouse.isDown(2))
        or (button == 2 and mouse.isDown(1))
        or (data.state[index] == Cell.uncover and button == 2 and state ~= Cell.flag)
        or data.chording
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

function data:set_state(state)
    if state == self.gamestate then return false end
    self.gamestate = state

    if state == GameStates.victory then
        for y = 0, self.height - 1 do
            for x = 0, self.width - 1 do
                local index = y * self.width + x
                local id = self.tilemap:get_id(x, y)

                if self.grid[index] < 0
                    and tile_to_state[id] ~= Cell.flag
                then
                    local px = x * tile
                    local py = y * tile
                    self.tilemap:insert_tile(px, py, state_to_tile[Cell.flag])
                    self.number_tilemap:insert_tile(px, py)
                end
            end
        end
    end
    return true
end

local function mousereleased(x, y, button, istouch, presses)
    if istouch then return end

    local mx, my = State:get_mouse_position() --data.get_mouse_position()
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

            if data:verify_victory() then
                data:set_state(GameStates.victory)
            end
        end
        data.chording = false
        ---
    elseif is_inside_board and state ~= Cell.uncover and allow_click then
        if button == 2 then
            if state == Cell.flag then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                data.number_tilemap:insert_tile(px, py, 9)
                data.state[index] = Cell.cover
                ---
            elseif data.number_tilemap:get_id(px, py) == 10 then
                -- SUSPICIOUS
                data.number_tilemap:insert_tile(px, py)
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                ---
            elseif data.state[index] == Cell.cover then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.flag])
                ---
            end
            reset_spritebatch = true

            ---
        elseif button == 1 then
            if data.grid[index] < 0 and state ~= Cell.flag then
                data:reveal_game()

                data.tilemap:insert_tile(px, py, state_to_tile[Cell.explosion])
                data.number_tilemap:insert_tile(px, py)
                ---
            elseif state ~= Cell.flag then
                data:unpress_cell(data.cell_x, data.cell_y)
                local r = pcall(data.uncover_cells_protected)

                if not r then
                    local cx, cy
                    local func = function()
                        data:unpress_cell(cx, cy)
                    end
                    for i = 1, 50 do
                        local index = data.last_index_uncover
                        cy = math.floor(index / data.width)
                        cx = index % data.width
                        pcall(func)
                    end
                end

                if data:verify_victory() then
                    data:set_state(GameStates.victory)
                end
                ---
                ---
            end

            reset_spritebatch = true
        end

        data.time_release = 0.06

        --
    else
        ---
        reset_spritebatch = data:unpress_cell(data.cell_x, data.cell_y)
        reset_spritebatch = data:unpress_cell(data.last_cell_x, data.last_cell_y) or reset_spritebatch
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

    local mx, my = State:get_mouse_position() --data.get_mouse_position()
    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)

    local cam = State.camera

    if dx and math.abs(dx) > 0 and dy and math.abs(dy) > 0 and mouse.isDown(1) and not data.chording then
        local ds = math.min((State.w - State.x) / State.screen_w,
            (State.h - State.y) / State.screen_h
        )
        -- data.dx = dx
        -- data.pressing = false
        data.time_click = 1
        cam:move(-dx / ds / cam.scale, -dy / ds / cam.scale)
    end


    local is_inside_board = position_is_inside_board(mx, my)

    local mx2, my2 = cam:world_to_screen(mx, my)
    cam:set_focus_x(mx2)
    cam:set_focus_y(my2)
    -- data.last_state = tile_to_state[data.tilemap:get_id(data.last_cell_x * tile, data.last_cell_y * tile)]

    if data.chording then
        if not is_inside_board then
            data:unpress_neighbor(data.last_cell_x, data.last_cell_y)
            data:unpress_neighbor(data.cell_x, data.cell_y)
            reset_spritebatch = true
        else
            data:unpress_neighbor(data.last_cell_x, data.last_cell_y)
            data:press_neighbor(data.cell_x, data.cell_y)
            reset_spritebatch = true
        end
    elseif not is_inside_board then
        reset_spritebatch = data:unpress_cell(data.last_cell_x, data.last_cell_y) or reset_spritebatch

        ---
    elseif data.pressing then
        local px = data.last_cell_x * tile
        local py = data.last_cell_y * tile

        local id = data.tilemap:get_id(px, py)
        local last_state = tile_to_state[id]

        if (last_state == Cell.press)
            or (mouse.isDown(1) or mouse.isDown(2))
        then
            reset_spritebatch = data:unpress_cell(data.last_cell_x, data.last_cell_y) or reset_spritebatch

            reset_spritebatch = data:press_cell(data.cell_x, data.cell_y) or reset_spritebatch
        end
    end

    data.last_cell_x = data.cell_x
    data.last_cell_y = data.cell_y


    if reset_spritebatch then
        data.tilemap:reset_spritebatch()
    end
end

local function wheelmoved(x, y)
    local cam = State.camera
    do
        local zoom = 0
        local speed = 1.5
        local dt = love.timer.getDelta()

        if y and y > 0 then
            zoom = cam.scale + speed * dt
        else
            zoom = cam.scale - speed * dt
        end
        zoom = Utils:clamp(zoom, cam.min_zoom, cam.max_zoom)
        cam:set_zoom(zoom)
    end

    local minscale = MIN_SCALE_TO_LOW_RES
    if cam.scale < minscale then
        data.tilemap:change_tileset(data.low_tileset)
    else
        data.tilemap:change_tileset(data.full_tileset)
    end
end

local function touchpressed(id, x, y, dx, dy, pressure)
    mousepressed(x, y, 1)
end

local function touchreleased(id, x, y, dx, dy, pressure)
    mousereleased(x, y, 1)
end

local function touchmoved(id, x, y, dx, dy, pressure)
    mousemoved(x, y, dx, dy)
end

local function gamepadpressed(joystick, button)

end

local function gamepadreleased(joystick, button)

end

local function resize(w, h)
    State.w = w
    State.h = h
    State:calc_canvas_scale()
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
        mousemoved()
    elseif controller:pressing(controller.Button.dpad_left) then
        cam:move(-speed * dt)
        mousemoved()
    end

    if controller:pressing(controller.Button.dpad_down) then
        cam:move(0, speed * dt)
        mousemoved()
    elseif controller:pressing(controller.Button.dpad_up) then
        cam:move(0, -speed * dt)
        mousemoved()
    end

    -- if data:verify_victory() then
    --     data.gamestate = GameStates.victory
    -- end
end

local layer_main = {
    ---@param cam JM.Camera.Camera
    draw = function(self, cam)
        if cam == data.cam2 then return end

        local font = JM.Font.current

        data.tilemap:draw(cam)
        data.number_tilemap:draw(cam)

        local px = data.cell_x * tile
        local py = data.cell_y * tile
        lgx.setColor(1, 0, 0, 0.7)
        lgx.rectangle(cam.scale < MIN_SCALE_TO_LOW_RES and "fill" or "line", px, py, tile, tile)

        -- love.graphics.setColor(1, 0, 0, 0.3)
        -- local mx, my = data.get_mouse_position(cam)
        -- love.graphics.circle("fill", mx, my, 1)

        -- local px = 0
        -- local py = 0
        -- for y = 0, data.height - 1 do
        --     for x = 0, data.width - 1 do
        --         local index = (y * data.width) + x
        --         local cell = data.grid[index]

        --         if cell == Cell.bomb then
        --             love.graphics.setColor(0, 0, 0, 0.12)
        --             love.graphics.circle("fill", px + 8, py + 8, 4)
        --         else
        --             if cell and cell > 0 then
        --                 font:push()
        --                 font:set_color(Utils:get_rgba(0, 0, 0, 0.12))
        --                 font:print(tostring(cell), tile * x + 4, tile * y + 4)
        --                 font:pop()
        --             end
        --         end
        --         px = px + tile
        --     end
        --     py = py + tile
        --     px = 0
        -- end

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
        -- font:print(tostring(data.dx), 20, 150)
        local vx, vy, vw, vh = State.camera:get_viewport_in_world_coord()
        font:print(string.format("%f\n %f\n %f\n %f", vx, vy, vw, vh), 20, 120)

        font:print(data.gamestate == GameStates.victory and "Victory" or "playing", 70, 120)
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
    wheelmoved = wheelmoved,
    touchpressed = touchpressed,
    touchreleased = touchreleased,
    gamepadpressed = gamepadpressed,
    gamepadreleased = gamepadreleased,
    resize = resize,
    update = update,
    layers = layers,
}

return State
