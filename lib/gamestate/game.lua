local path = ...
local JM = _G.JM_Package
local TileMap = JM.TileMap
local Utils = JM.Utils
local TileSet = JM.TileSet

local Timer = require "lib.timer"
local Board = require "lib.board"

do
    _G.SUBPIXEL = _G.SUBPIXEL or 3
    _G.CANVAS_FILTER = _G.CANVAS_FILTER or 'linear'
    _G.TILE = _G.TILE or 16
end


---@class Gamestate.Game : JM.Scene
local State = JM.Scene:new {
    x = nil, --100,
    y = nil, --0,
    w = nil, --love.graphics.getWidth() - 200,
    h = nil, --love.graphics.getHeight() / 2,
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
    -- show_border = true,
    -- use_vpad = true,
}

State:add_camera {
    name = "cam2",
    -- border_color = Utils:get_rgba(),
}

State:add_camera {
    name = "cam3",
}

local cam_gui = State.camera              --State:get_camera("cam2")

local cam_game = State:get_camera("cam2") --State.camera

local cam_buttons = State:get_camera("cam3")

-- cam_game:toggle_grid()
-- cam_game:toggle_world_bounds()
-- cam_game:toggle_debug()

---@enum Gamestate.Game.Modes
local GameMode = {
    standard = 0,
    beginner = 1,
    intermediate = 2,
    expert = 3,
    custom = 4,
}

local GameStates = {
    victory = 1,
    dead = 2,
    playing = 3,
    resume = 4,
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
    [8] = Cell.press,
    [9] = Cell.press,
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
    return x >= 0 and x <= data.width * tile and y >= 0 and y <= data.height * tile and
        cam_game:point_is_on_screen(x, y)
end

local vibrate = function()
    return love.system.vibrate(0.3)
end

local generic = function()

end

---@param orientation "portrait"|"landscape"|any
data.change_orientation = function(self, orientation)
    orientation = orientation or "landscape"

    if orientation == "landscape" then
        cam_gui:set_viewport(
            State.screen_w * 0,
            nil,
            State.screen_w * 1,
            State.screen_h
        )

        cam_game:set_viewport(
            8,
            8,
            State.screen_w * 0.75 - 16,
            State.screen_h - 16 - 16
        )

        cam_buttons:set_viewport(0, 0, State.screen_w, State.screen_h)

        if data.timer then
            data.timer.x = 320
            data.timer.y = 16
        end

        if data.width and data.height then
            local cam = cam_game
            local z = cam.viewport_h / (data.height * tile)
            cam:set_zoom(z)
            cam:set_position(-math.abs((data.width * tile) - cam.viewport_w / cam.scale) / 2, 0)
        end

        if data.bt_click then
            data.bt_click:set_position(cam_game.viewport_w + 20, 110)
        end

        if data.bt_main then
            data.bt_main:set_position(cam_game.viewport_w + 20, data.bt_click.bottom + 12)
        end
    else
        cam_gui:set_viewport(
            State.screen_w * 0,
            State.screen_h * 0,
            State.screen_w * 1,
            State.screen_h
        )

        local tw = 9
        local th = 15

        local w = tw * tile
        local sc = (State.screen_w - 8) / w
        local h = th * tile
        local x = (State.screen_w - w) / 2
        local y = tile * 3
        cam_game:set_viewport(
            4,
            tile * 3,
            w * sc,
            h * sc
        )

        cam_buttons:set_viewport(0, 0, State.screen_w, State.screen_h)


        -- if data.width and data.height then
        if tw <= th then
            local cam = cam_game
            local z = cam.viewport_w / (tw * tile)
            cam:set_zoom(z)
            cam:set_position(0, -math.abs((th * tile) - cam.viewport_h / cam.scale) / 2)
        else
            local cam = cam_game
            local z = cam.viewport_h / (th * tile)
            cam:set_zoom(z)
            cam:set_position(-math.abs((tw * tile) - cam.viewport_w / cam.scale) / 2, 0)
        end

        if data.timer then
            data.timer.x = cam_gui.viewport_w - 64
            data.timer.y = 16
        end

        if data.bt_click then
            data.bt_click:set_position(64, cam_game.viewport_y + cam_game.viewport_h + 10)
        end

        if data.bt_main then
            data.bt_main:set_position(data.bt_click.right + 16, data.bt_click.y)
        end
        -- end
    end
    data.orientation = orientation
end
--============================================================================

function State:__get_data__()
    return data
end

local function load()
    Timer:load()
    Board:load()
end

local function finish()
    Timer:finish()
    Board:finish()
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
    data:change_orientation(State.screen_h > State.screen_w and "portrait" or "landscape")

    data.world = JM.Physics:newWorld {
        tile = tile,
        cellsize = tile * 4,
    }
    JM.GameObject:init_state(State, data.world)

    State.game_objects = {}

    data.tilemap = TileMap:new(generic, "data/img/tilemap.png", 16)
    data.number_tilemap = TileMap:new(generic, "data/img/number_tilemap.png", 16)

    data.full_tileset = data.tilemap.tile_set
    data.low_tileset = TileSet:new("data/img/tilemap-low.png", 16)

    data.height = 15 --+ 4
    data.width = 9   --+ 4
    data.mines = 20  --Utils:round(16 * 16 * 0.2)
    data.flags = 0
    data.time_game = 0.0
    data.grid = setmetatable({}, meta_grid)
    data.state = setmetatable({}, meta_state)
    data.first_click = true
    data.continue = 2
    data.time_click = 0.0
    -- data.time_release = 0.0
    data.pressing = false
    data.touches_ids = {}
    data.n_touches = 0
    data.gamestate = GameStates.playing
    data.click_state = ClickState.reveal
    data.direction_x = 0
    data.direction_y = 0
    mouse.setVisible(true)

    State:set_color(0.5, 0.5, 0.5, 1)

    local cam = cam_game --State.camera

    local off = Utils:round(data.width / 8 * 15)
    cam:set_bounds(-tile * off,
        data.width * tile + tile * off,
        -tile * off,
        data.height * tile + tile * off)

    cam:set_position(0, 0)
    cam.scale = 1
    cam.min_zoom = 0.015
    cam.max_zoom = 2


    cam:keep_on_bounds()

    -- filling tilemap with cover cells
    for y = 0, data.height - 1 do
        for x = 0, data.width - 1 do
            data.tilemap:insert_tile(x * tile, y * tile, state_to_tile[Cell.cover])
        end
    end

    data.cell_x = 0
    data.cell_y = 0

    data.last_cell_x = data.cell_x
    data.last_cell_y = data.cell_y

    data.uncover_cells_protected = function()
        data:uncover_cells(data.cell_x, data.cell_y)
    end

    data.timer = Timer:new()
    data.timer:lock()
    State:add_object(data.timer)

    data.container = JM.GUI.Container:new {
        x = 0, y = 0,
        w = 2000, h = 2000,
        scene = State,
        -- on_focus = true,
    }

    data.bt_click = JM.GUI.Button:new {
        x = 20, y = 20, w = 32, h = 32, on_focus = true,
        text = "click",
    }
    data.bt_click:on_event("mouse_pressed", function()
        data.click_state = data.click_state == ClickState.reveal and ClickState.flag or ClickState.reveal
    end)

    data.bt_main = JM.GUI.Button:new {
        x = 0, y = 0, w = 32, h = 32, on_focus = true, text = "main"
    }

    data.bt_main:on_event("mouse_pressed", function()
        if data.continue > 0 and data.gamestate == GameStates.dead then
            data:revive()
        else
            State:init()
        end
    end)



    data.container:add(data.bt_click)
    data.container:add(data.bt_main)

    data:change_orientation(State.screen_h > State.screen_w and "portrait" or "landscape")
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
        local cam = cam_game
        cam:toggle_grid()
        cam:toggle_world_bounds()
        cam:toggle_debug()
    end
    if key == 'p' then
        local cam = cam_gui
        cam:toggle_grid()
        cam:toggle_world_bounds()
        -- cam:toggle_debug()
    end

    if key == 'v' then
        if data.orientation == "landscape" then
            State:change_game_screen(224, 485)
            data:change_orientation("portrait")
        else
            State:change_game_screen(398, 224)
            data:change_orientation("landscape")
        end
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

        self:uncover_cells(cellx - 1, celly - 1)
        self:uncover_cells(cellx, celly - 1)
        self:uncover_cells(cellx + 1, celly - 1)
        self:uncover_cells(cellx - 1, celly)
        self:uncover_cells(cellx + 1, celly)
        self:uncover_cells(cellx - 1, celly + 1)
        self:uncover_cells(cellx, celly + 1)
        self:uncover_cells(cellx + 1, celly + 1)

        -- self:uncover_cells(cellx - 1, celly)
        -- self:uncover_cells(cellx - 1, celly - 1)
        -- self:uncover_cells(cellx, celly - 1)
        -- self:uncover_cells(cellx + 1, celly)
        -- self:uncover_cells(cellx - 1, celly + 1)
        -- self:uncover_cells(cellx, celly + 1)
        -- self:uncover_cells(cellx + 1, celly - 1)
        -- self:uncover_cells(cellx + 1, celly + 1)

        ---
    elseif value > 0 and state ~= Cell.flag then
        self.state[index] = Cell.uncover

        self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        self.number_tilemap:insert_tile(px, py, value)
        return true
    else
        return false
    end
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
    if self.continue <= 0 then return false end

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
                self.flags = self.flags + 1
            end
        end
    end

    self.continue = self.continue - 1
    self:set_state(GameStates.resume)
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
    local cell_value = self.grid[index]

    if cell_value > 0 and state ~= Cell.cover then
        local count_flags = self:count_neighbor_flags(cellx, celly)
        local r1, r2, r3, r4, r5, r6, r7, r8

        if count_flags == cell_value then
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
                self:set_state(GameStates.dead)
                self.tilemap:reset_spritebatch()
            end
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

        self.timer:lock()
        ---
    elseif state == GameStates.dead then
        self.timer:lock()
        vibrate()
        ---
    elseif state == GameStates.playing then
        ---
    elseif state == GameStates.resume then
        self.timer:unlock()
        self:set_state(GameStates.playing)
        ---
    end
    return true
end

local function mousepressed(x, y, button, istouch, presses, mx, my)
    local on_mobile = _G.TARGET == "Android"
    local px, py = State:get_mouse_position(cam_buttons)
    if on_mobile then
        px = mx or px
        py = my or py
    end

    data.container:mouse_pressed(px, py, button, istouch, presses)

    if istouch or data.gamestate ~= GameStates.playing then
        return
    end

    if not mx or not my then
        mx, my = State:get_mouse_position(cam_game)
    end

    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)

    local is_inside_board = position_is_inside_board(mx, my)

    data.pressing = true
    if not is_inside_board or button > 2 then return end


    local px = data.cell_x * tile
    local py = data.cell_y * tile
    local id = data.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = data.cell_y * data.width + data.cell_x

    if (button == 1 and not on_mobile and mouse.isDown(2))
        or (button == 2 and not on_mobile and mouse.isDown(1))
        or (data.state[index] == Cell.uncover and (button == 2 or on_mobile) and state ~= Cell.flag)
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

local function mousereleased(x, y, button, istouch, presses, mx, my)
    data.moving = false

    local on_mobile = _G.TARGET == "Android"
    local px, py = State:get_mouse_position(cam_buttons)
    if on_mobile then
        px = mx or px
        py = my or py
    end
    data.container:mouse_released(px, py, button, istouch, presses)

    if istouch or data.gamestate ~= GameStates.playing then return end

    if not mx or not my then
        mx, my = State:get_mouse_position(cam_game)
    end

    local is_inside_board = position_is_inside_board(mx, my)

    local px = data.cell_x * tile
    local py = data.cell_y * tile
    local id = data.tilemap:get_id(px, py)
    local state = tile_to_state[id]
    local index = data.cell_y * data.width + data.cell_x
    local reset_spritebatch = false
    local allow_click = data.time_click < 0.5
        and data.pressing
    -- and data.time_release <= 0.0

    if data.first_click and is_inside_board and button == 1
        and state ~= Cell.flag
        and allow_click
        and not data.chording
    then
        data.first_click = false
        data:build_board(data.cell_y * data.width + data.cell_x)
        data.timer:unlock()
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
                data.flags = data.flags - 1
                ---
            elseif data.number_tilemap:get_id(px, py) == 10 then
                -- SUSPICIOUS
                data.number_tilemap:insert_tile(px, py)
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.cover])
                ---
            elseif data.state[index] == Cell.cover then
                data.tilemap:insert_tile(px, py, state_to_tile[Cell.flag])
                data.flags = data.flags + 1
                ---
            end
            reset_spritebatch = true

            ---
        elseif button == 1 then
            if data.grid[index] < 0 and state ~= Cell.flag then
                data:reveal_game()
                data:set_state(GameStates.dead)

                data.tilemap:insert_tile(px, py, state_to_tile[Cell.explosion])
                data.number_tilemap:insert_tile(px, py)
                ---
            elseif state ~= Cell.flag then
                data:unpress_cell(data.cell_x, data.cell_y)
                local r = pcall(data.uncover_cells_protected)

                -- if not r then
                --     local cx, cy
                --     local func = function()
                --         data:unpress_cell(cx, cy)
                --     end
                --     for i = 1, 50 do
                --         local index = data.last_index_uncover
                --         cy = math.floor(index / data.width)
                --         cx = index % data.width
                --         pcall(func)
                --     end
                -- end

                if data:verify_victory() then
                    data:set_state(GameStates.victory)
                end
                ---
                ---
            end

            reset_spritebatch = true
        end

        -- data.time_release = 0.06

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

local function mousemoved(x, y, dx, dy, istouch, mouseIsDown1, mouseIsDown2, mx, my)
    if istouch then return end

    local reset_spritebatch = false
    local cam = cam_game --State.camera

    if not mx or not my then
        mx, my = State:get_mouse_position(cam_game)
    end

    local is_inside_board = position_is_inside_board(mx, my)
    data.cell_x = Utils:clamp(floor(mx / tile), 0, data.width - 1)
    data.cell_y = Utils:clamp(floor(my / tile), 0, data.height - 1)


    if ((dx and math.abs(dx) > 1) or (dy and math.abs(dy) > 1))
        and (mouseIsDown1 or mouse.isDown(1)) and not data.chording
        and cam:point_is_on_view(mx, my)
    then
        local qx = State:monitor_length_to_world(dx, cam_game)
        local qy = State:monitor_length_to_world(dy, cam_game)

        cam:move(-qx, -qy)

        if math.abs(dx) > 3 or math.abs(dy) > 3 then
            data.time_click = 0.51 --1000
            data.moving = true
        end
    end


    local mx2, my2 = cam:world_to_screen(mx, my)
    cam:set_focus(mx2, my2)


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
            or (mouseIsDown1 or mouse.isDown(1)
                or mouseIsDown2 or mouse.isDown(2))
        then
            reset_spritebatch = data:unpress_cell(data.last_cell_x, data.last_cell_y) or reset_spritebatch

            reset_spritebatch = data:press_cell(data.cell_x, data.cell_y) or reset_spritebatch

            data.moving = true
        end
    end

    data.last_cell_x = data.cell_x
    data.last_cell_y = data.cell_y


    if reset_spritebatch then
        data.tilemap:reset_spritebatch()
    end
end

local function wheelmoved(x, y, force_zoom)
    local cam = cam_game --State.camera
    local is_inside_board = cam:point_is_on_screen(State:get_mouse_position(cam_game))

    if force_zoom or is_inside_board then
        local zoom = cam.scale
        local speed = 0.1

        if y > 0 then
            zoom = cam.scale + speed
        else
            zoom = cam.scale - speed
        end

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
    if data.n_touches < 2 then
        data.n_touches = data.n_touches + 1
        local tab = {}
        data.touches_ids[id] = tab --data.touches[N]

        tab.x = x
        tab.y = y
        tab.lx = x
        tab.ly = y
        tab.dx = dx
        tab.dy = dy
        tab.id = id
    end

    if data.n_touches <= 1 and data.touches_ids[id] then
        local mx, my = State:point_monitor_to_world(x, y, cam_game)
        local bt = data.click_state == ClickState.reveal and 1 or 2

        return mousepressed(mx, my, bt, nil, nil, mx, my)
        ---
    elseif data.n_touches == 2 then

    end
end

local function touchreleased(id, x, y, dx, dy, pressure)
    if data.touches_ids[id] then
        data.n_touches = data.n_touches - 1
        data.touches_ids[id] = nil

        local mx, my = State:point_monitor_to_world(x, y, cam_game)
        local bt = data.click_state == ClickState.reveal and 1 or 2
        return mousereleased(mx, my, bt, nil, nil, mx, my)
    end
end

local function touchmoved(id, x, y, dx, dy, pressure)
    local touch = data.touches_ids[id]

    if touch then
        touch.lx = touch.x
        touch.ly = touch.y
        touch.x = x
        touch.y = y
        touch.dx = dx
        touch.dy = dy

        -- only move the board if exactly one touch is active
        if data.n_touches == 1 then
            local mx, my = State:point_monitor_to_world(x, y, cam_game)
            mousemoved(mx, my, dx, dy, nil, true, nil, mx, my)
            ---
        elseif data.n_touches == 2 then
            local touch1, touch2
            for key, value in pairs(data.touches_ids) do
                if not touch1 then
                    touch1 = value --data.touches_ids[key]
                else
                    touch2 = value --data.touches_ids[key]
                    break
                end
            end

            if touch2.y < touch1.y then
                touch1, touch2 = touch2, touch1
            end

            local cam = cam_game

            local mx1, my1 = State:point_monitor_to_world(touch1.x, touch1.y, cam)
            local mx2, my2 = State:point_monitor_to_world(touch2.x, touch2.y, cam)


            local dx1 = State:monitor_length_to_world(touch1.dx, cam)
            local dy1 = State:monitor_length_to_world(touch1.dy, cam)
            local dx2 = State:monitor_length_to_world(touch2.dx, cam)
            local dy2 = State:monitor_length_to_world(touch2.dy, cam)

            local rw = math.abs(mx1 - mx2)
            local rh = math.abs(my1 - my2)
            local rx = mx1 < mx2 and mx1 or mx2
            local ry = my1

            cam:set_focus(cam:world_to_screen(rx + rw * 0.5, ry + rh * 0.5))

            if (dy1 <= 0 and dy2 > 0) then
                wheelmoved(nil, 1, true)
            elseif dy1 >= 0 and dy2 < 0 then
                wheelmoved(nil, -1, true)
            end
            ---
        end
    end
end

local function gamepadpressed(joystick, button)
    local controller = JM.ControllerManager.P1
    local Button = controller.Button

    local mx, my = data.cell_x * tile, data.cell_y * tile

    if controller:pressed(Button.A, joystick, button) then
        local index = data.cell_y * data.width + data.cell_x

        local bt = data.grid[index] >= 0
            and data.state[index] == Cell.uncover
            and 2 or 1
        mousepressed(mx, my, bt, nil, nil, mx, my)
        ---
    elseif controller:pressed(Button.B, joystick, button) then
        local id = data.number_tilemap:get_id(mx, my)

        if id == 10 or id == 9
            or tile_to_state[data.tilemap:get_id(mx, my)] == Cell.flag
        then
            mousepressed(mx, my, 2, nil, nil, mx, my)
            mousereleased(mx, my, 2, nil, nil, mx, my)
            data.time_click = 0
            mousepressed(mx, my, 2, nil, nil, mx, my)
            mousereleased(mx, my, 2, nil, nil, mx, my)
        else
            mousepressed(mx, my, 2, nil, nil, mx, my)
        end
        ---
    elseif controller:pressed(Button.Y, joystick, button) then
        local id = data.number_tilemap:get_id(mx, my)

        if tile_to_state[data.tilemap:get_id(mx, my)] == Cell.flag
            or id == 9 or id == 10
        then
            mousepressed(mx, my, 2, nil, nil, mx, my)
            mousereleased(mx, my, 2, nil, nil, mx, my)
        else
            mousepressed(mx, my, 2, nil, nil, mx, my)
            mousereleased(mx, my, 2, nil, nil, mx, my)
            data.time_click = 0
            mousepressed(mx, my, 2, nil, nil, mx, my)
            mousereleased(mx, my, 2, nil, nil, mx, my)
        end
    end
end

local function gamepadreleased(joystick, button)
    local controller = JM.ControllerManager.P1
    local Button = controller.Button

    local mx, my = data.cell_x * tile, data.cell_y * tile

    if controller:released(Button.A, joystick, button) then
        mousereleased(mx, my, 1, nil, nil, mx, my)
    elseif controller:released(Button.B, joystick, button) then
        mousereleased(mx, my, 2, nil, nil, mx, my)
    end
end

---@param joy love.Joystick
---@param axis love.GamepadAxis
---@param value any
local function gamepadaxis(joy, axis, value)
    local controller = JM.ControllerManager.P1
    local Button = controller.Button

    local mx, my = data.cell_x * tile, data.cell_y * tile
end

local function resize(w, h)
    local on_mobile = _G.TARGET == "Android"
    local orientation = w > h and "landscape" or "portrait"

    local dw, dh

    if on_mobile then
        if orientation == "landscape" then
            dw, dh = 485, 224
        else
            dw, dh = 224, 485
        end
    else -- On PC
        if orientation == "landscape" then
            dw, dh = 398, 224
        else
            dw, dh = 224, 485
        end
    end

    State:change_game_screen(dw, dh)

    data:change_orientation(State.screen_h > State.screen_w and "portrait" or "landscape")
end


local function update(dt)
    State:update_game_objects(dt)
    data.container:update(dt)

    if data.pressing then
        local mx, my = data.cell_x * tile, data.cell_y * tile
        if _G.TARGET == "Android" and data.time_click >= 0.6
            and not data.moving
            and position_is_inside_board(State:get_mouse_position(cam_game))
            and not data.chording
        then
            local id = data.tilemap:get_id(mx, my)

            if tile_to_state[id] == Cell.press
            -- or id == 8 or id == 9
            then
                data.time_click = 0
                mousereleased(mx, my, 2, nil, nil, mx, my)
                vibrate()
            end
        end

        data.time_click = data.time_click + dt
    end

    local cam = cam_game --State.camera
    local speed = 32
    local controller = JM.ControllerManager.P1
    local Button = controller.Button

    if controller.state == controller.State.keyboard then
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
        ---
    elseif controller.state == controller.State.joystick then
        ---
        local mx, my = data.cell_x * tile, data.cell_y * tile

        controller.time_delay_button[Button.L2] = 0.1
        local tr = controller:pressing_time(Button.L2)
        if tr and tr > 0 then
            cam_game:set_focus(cam_game:world_to_screen(mx + tile * 0.5, my + tile * 0.5))
            wheelmoved(0, -1, true)
        end
        controller.time_delay_button[Button.R2] = 0.1
        tr = controller:pressing_time(Button.R2)
        if tr and tr > 0 then
            cam_game:set_focus(cam_game:world_to_screen(mx + tile * 0.5, my + tile * 0.5))
            wheelmoved(0, 1, true)
        end


        local axis_right_x = controller:pressing(Button.right_stick_x)
        if axis_right_x < -0.5 then
            cam:move(-speed * dt)
            if data.cell_x * tile + tile > cam.x + cam.viewport_w / cam.scale then
                data.cell_x = Utils:clamp(math.floor((cam.x + cam.viewport_w / cam.scale - tile) / tile), 0,
                    data.width - 1)
            end
        elseif axis_right_x > 0.5 then
            cam:move(speed * dt)
            if data.cell_x * tile < cam_game.x then
                data.cell_x = Utils:clamp(math.floor((cam.x + tile) / tile), 0, data.width - 1)
            end
        end

        local axis_right_y = controller:pressing(Button.right_stick_y)
        if axis_right_y < -0.5 then
            cam:move(0, -speed * dt)
            if data.cell_y * tile + tile > cam.y + cam.viewport_h / cam.scale then
                data.cell_y = Utils:clamp(math.floor((cam.y + cam.viewport_h / cam.scale - tile) / tile), 0,
                    data.height - 1)
            end
        elseif axis_right_y > 0.5 then
            cam:move(0, speed * dt)
            if data.cell_y * tile < cam_game.y then
                data.cell_y = Utils:clamp(math.floor((cam.y + tile) / tile), 0, data.height - 1)
            end
        end

        if data.direction_x == 0 then
            controller.time_delay_button[Button.left_stick_x] = 0.5
        else
            controller.time_delay_button[Button.left_stick_x] = 0.1
        end

        local axis_x = controller:pressing_time(Button.left_stick_x)

        if axis_x and axis_x > 0 then
            data.cell_x = Utils:clamp(data.cell_x + 1, 0, data.width - 1)

            data.direction_x = 1
            local mx, my = data.cell_x * tile, data.cell_y * tile
            mousemoved(nil, nil, nil, nil, nil, controller:pressing(Button.A), controller:pressing(Button.B), mx, my)
            ---
        elseif axis_x and axis_x < 0 then
            data.cell_x = Utils:clamp(data.cell_x - 1, 0, data.width - 1)

            data.direction_x = -1
            local mx, my = data.cell_x * tile, data.cell_y * tile
            mousemoved(nil, nil, nil, nil, nil, controller:pressing(Button.A), controller:pressing(Button.B), mx, my)
            ---
        elseif (controller:pressing(Button.left_stick_x)) == 0 then
            data.direction_x = 0
        end

        if data.direction_y == 0 then
            controller.time_delay_button[Button.left_stick_y] = 0.5
        else
            controller.time_delay_button[Button.left_stick_y] = 0.1
        end
        local axis_y = controller:pressing_time(Button.left_stick_y)

        if axis_y and axis_y > 0 then
            data.cell_y = Utils:clamp(data.cell_y + 1, 0, data.height - 1)
            data.direction_y = 1
            local mx, my = data.cell_x * tile, data.cell_y * tile
            mousemoved(nil, nil, nil, nil, nil, controller:pressing(Button.A), controller:pressing(Button.B), mx, my)
            ---
        elseif axis_y and axis_y < 0 then
            data.cell_y = Utils:clamp(data.cell_y - 1, 0, data.height - 1)
            data.direction_y = -1
            local mx, my = data.cell_x * tile, data.cell_y * tile
            mousemoved(nil, nil, nil, nil, nil, controller:pressing(Button.A), controller:pressing(Button.B), mx, my)
            ---
        elseif controller:pressing(Button.left_stick_y) == 0 then
            data.direction_y = 0
        end
    end

    if data.gamestate == GameStates.playing then
        data.time_game = data.time_game + dt
    end
end

local layer_main = {
    ---@param cam JM.Camera.Camera
    draw = function(self, cam)
        -- if cam == data.cam2 then return end
        if cam ~= cam_game then return end

        love.graphics.setColor(179 / 255, 185 / 255, 209 / 255)
        love.graphics.rectangle("fill", cam:get_viewport_in_world_coord())

        local font = JM.Font.current

        data.tilemap:draw(cam)
        data.number_tilemap:draw(cam)

        local px = data.cell_x * tile
        local py = data.cell_y * tile
        lgx.setColor(1, 0, 0, 0.7)
        lgx.rectangle(cam.scale < MIN_SCALE_TO_LOW_RES and "fill" or "line", px, py, tile, tile)

        -- love.graphics.setColor(1, 0, 0, 0.3)
        -- local mx, my = State:get_mouse_position(cam)
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
        -- if cam == State.camera then return end
        if cam ~= cam_gui then return end

        love.graphics.setColor(88 / 255, 141 / 255, 190 / 255)
        love.graphics.rectangle("fill", cam:get_viewport_in_world_coord())

        local font = JM.Font.current
        -- do
        --     -- lgx.push()
        --     -- lgx.translate(cam_game.viewport_w - cam_game.viewport_x, 0)
        --     -- font:print("Continue " .. tostring(data.continue), 20, 90)
        --     -- -- font:print(tostring(data.dx), 20, 150)
        --     -- local vx, vy, vw, vh = cam_game:get_viewport_in_world_coord()
        --     -- vx = cam_game.x
        --     -- vy = cam_game.y
        --     -- font:print(string.format("%f\n %f\n %f\n %f", vx, vy, vw, vh), 20, 120)

        --     -- font:print(data.gamestate == GameStates.victory and "Victory" or "playing", 70, 120)

        --     -- local mx, my = State:get_mouse_position(cam_game)
        --     -- local view = position_is_inside_board(mx, my)
        --     -- font:print(cam_game:point_is_on_view(mx, my) and "True" or "False", 50, 66)

        --     -- font:print(string.format("%f %f", mx, my), 120, 10)

        --     -- lgx.pop()
        -- end

        if data.orientation == "landscape" then
            font:print(string.format("Mines: %d", data.mines - data.flags), cam_game.viewport_w + 20, 32)

            local r = data.gamestate == GameStates.playing and "playing"
            r = not r and data.gamestate == GameStates.dead and "dead" or r
            r = not r and data.gamestate == GameStates.victory and "victory" or r
            r = not r and "Error" or r

            font:print(tostring(r), cam_game.viewport_w + 20, 64)

            r = data.click_state == ClickState.reveal and "reveal"
            r = not r and data.click_state == ClickState.flag and "flag" or r
            font:print(tostring(r), cam_game.viewport_w + 20, 64 + 16)
        else
            font:print(string.format("Mines: %d", data.mines - data.flags), 20, 16)

            local r = data.gamestate == GameStates.playing and "playing"
            r = not r and data.gamestate == GameStates.dead and "dead" or r
            r = not r and data.gamestate == GameStates.victory and "victory" or r
            r = not r and "Error" or r
            font:print(tostring(r), 20, cam_game.viewport_y + cam_game.viewport_h)

            r = data.click_state == ClickState.reveal and "reveal"
            r = not r and data.click_state == ClickState.flag and "flag" or r
            font:print(tostring(r), 20, cam_game.viewport_y + cam_game.viewport_h + 16)
        end

        State:draw_game_object(cam)
    end
}

local layer_buttons = {
    name = "buttons",
    ---
    draw = function(self, cam)
        if cam ~= cam_buttons then return end
        data.container:draw(cam)
    end
}

local layers = {
    --
    layer_gui,
    layer_main,
    layer_buttons,
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
    touchmoved = touchmoved,
    gamepadpressed = gamepadpressed,
    gamepadreleased = gamepadreleased,
    gamepadaxis = gamepadaxis,
    resize = resize,
    update = update,
    layers = layers,
}

return State
