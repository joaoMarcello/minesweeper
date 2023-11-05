local GC = _G.JM.GameObject
local TileMap = _G.JM.TileMap
local TileSet = _G.JM.TileSet
local Utils = _G.JM.Utils

-- local GameStates = {
--     victory = 1,
--     dead = 2,
--     playing = 3,
--     resume = 4,
-- }

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

local meta_grid = { __index = function() return 0 end }
local meta_state = { __index = function() return Cell.cover end }

--===========================================================================
local tile = _G.TILE
local rand, floor = math.random, math.floor

local shuffle = function(t, n)
    local N = n or #t
    for i = N, 2, -1 do
        local j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
end

---@param self Board
local function increment(self, x, y)
    if x < 0 or y < 0 then return false end
    if x > self.width - 1 or y > self.height - 1 then return false end

    local index = y * self.width + x
    if index >= self.width * self.height then return false end

    local cell = self.grid[index]
    if cell == Cell.bomb then return false end
    -- data.grid[index] = data.grid[index] or 0
    self.grid[index] = self.grid[index] + 1
    return true
end

---@param self Board
---@return boolean
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

---@param self Board
local function is_flag(self, cellx, celly)
    if cellx < 0 or celly < 0 then return 0 end
    if cellx > self.width - 1 or celly > self.height - 1 then return 0 end

    local px = cellx * tile
    local py = celly * tile
    local id = self.tilemap:get_id(px, py)
    local state = id and tile_to_state[id]

    return (state == Cell.flag) and 1 or 0
end

local function generic() end
--===========================================================================
---@class Board : GameObject
local Board = setmetatable({
    Cell = Cell,
    tile_to_state = tile_to_state,
    state_to_tile = state_to_tile,
}, GC)

Board.__index = Board

---@return Board
function Board:new(x, y, w, h, draw_order, update_order, reuse_tab)
    local obj = GC:new(x, y, w, h, draw_order, update_order, reuse_tab)
    setmetatable(obj, self)
    Board.__constructor__(obj)
    return obj
end

function Board:__constructor__()
    self.tilemap = TileMap:new(generic, "data/img/tilemap.png", 16)
    self.number_tilemap = TileMap:new(generic, "data/img/number_tilemap.png", 16)

    self.full_tileset = self.tilemap.tile_set
    self.low_tileset = TileSet:new("data/img/tilemap-low.png", 16)

    self.height = 15 --+ 4
    self.width = 9   --+ 4
    self.mines = 20  --Utils:round(16 * 16 * 0.2)
    self.flags = 0
    self.chording = false

    self.grid = setmetatable({}, meta_grid)
    self.state = setmetatable({}, meta_state)
    -- self.first_click = true
    -- self.continue = 2
    -- self.boardstate = GameStates.playing

    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            self.tilemap:insert_tile(x * tile, y * tile, state_to_tile[Cell.cover])
        end
    end

    self.cell_x = 0
    self.cell_y = 0

    self.last_cell_x = self.cell_x
    self.last_cell_y = self.cell_y

    self.uncover_cells_protected = function()
        self:uncover_cells(self.cell_x, self.cell_y)
    end

    --
    self.update = Board.update
    self.draw = Board.draw
end

function Board:load()

end

function Board:init()

end

function Board:build(exception)
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
                increment(self, x - 1, y - 1)
                increment(self, x, y - 1)
                increment(self, x + 1, y - 1)
                increment(self, x - 1, y)
                increment(self, x + 1, y)
                increment(self, x - 1, y + 1)
                increment(self, x, y + 1)
                increment(self, x + 1, y + 1)
            end
        end
    end
end

function Board:cell_update(mx, my)
    self.cell_x = Utils:clamp(floor(mx / tile), 0, self.width - 1)
    self.cell_y = Utils:clamp(floor(my / tile), 0, self.height - 1)
end

function Board:verify_victory()
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

function Board:reveal_game()
    local has_continue = true --self.continue > 0
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

function Board:uncover_cells(cellx, celly)
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

    if value == 0 then
        self.state[index] = Cell.uncover

        if state ~= Cell.flag then
            self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
            self.number_tilemap:insert_tile(px, py)
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
    elseif value > 0 and state ~= Cell.flag then
        self.state[index] = Cell.uncover

        self.tilemap:insert_tile(px, py, state_to_tile[Cell.uncover])
        self.number_tilemap:insert_tile(px, py, value)
        return true
    else
        return false
    end
end

function Board:press_cell(cellx, celly, press_uncover)
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

function Board:unpress_cell(cellx, celly, unpress_uncover)
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

function Board:revive()
    -- if self.continue <= 0 then return false end

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

    -- self.continue = self.continue - 1
    -- self:set_state(GameStates.resume)
    return true
end

function Board:press_neighbor(cellx, celly)
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

function Board:unpress_neighbor(cellx, celly)
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

function Board:count_neighbor_flags(cellx, celly)
    if cellx < 0 or celly < 0 then return 0 end
    if cellx > self.width - 1 or celly > self.height - 1 then return 0 end

    local r = is_flag(self, cellx - 1, celly - 1)
    r = r + is_flag(self, cellx, celly - 1)
    r = r + is_flag(self, cellx + 1, celly - 1)
    r = r + is_flag(self, cellx - 1, celly)
    r = r + is_flag(self, cellx + 1, celly)
    r = r + is_flag(self, cellx - 1, celly + 1)
    r = r + is_flag(self, cellx, celly + 1)
    r = r + is_flag(self, cellx + 1, celly + 1)

    return r
end

function Board:reveal_cell(cellx, celly, show_explosion)
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

function Board:verify_chording(cellx, celly)
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
                -- self:set_state(GameStates.dead)
                self.tilemap:reset_spritebatch()
                return -1
            end
        end
    end

    return true
end

function Board:victory()
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

-- function Board:set_state(state)
--     if state == self.boardstate then return false end
--     self.boardstate = state

--     if state == GameStates.victory then
--         self:victory()
--         -- for y = 0, self.height - 1 do
--         --     for x = 0, self.width - 1 do
--         --         local index = y * self.width + x
--         --         local id = self.tilemap:get_id(x, y)

--         --         if self.grid[index] < 0
--         --             and tile_to_state[id] ~= Cell.flag
--         --         then
--         --             local px = x * tile
--         --             local py = y * tile
--         --             self.tilemap:insert_tile(px, py, state_to_tile[Cell.flag])
--         --             self.number_tilemap:insert_tile(px, py)
--         --         end
--         --     end
--         -- end

--         -- self.timer:lock()
--         ---
--     elseif state == GameStates.dead then
--         -- self.timer:lock()
--         -- vibrate()
--         ---
--     elseif state == GameStates.playing then
--         ---
--     elseif state == GameStates.resume then
--         -- self.timer:unlock()
--         self:set_state(GameStates.playing)
--         ---
--     end
--     return true
-- end

function Board:update(dt)

end

function Board:my_draw()
    local cam = self.gamestate:get_camera("cam2")
    self.tilemap:draw(cam)
    self.number_tilemap:draw(cam)
end

function Board:draw()
    GC.draw(self, self.my_draw)
end

return Board
