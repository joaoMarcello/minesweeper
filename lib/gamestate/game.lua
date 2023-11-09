local path = ...
local JM = _G.JM_Package
local TileMap = JM.TileMap
local Utils = JM.Utils
local TileSet = JM.TileSet
local Loader = JM.Ldr

do
    local Word = require "jm-love2d-package.modules.font.Word"
    ---@diagnostic disable: inject-field
    Word.eff_wave_range = 1
end

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

---@enum GameState.Game.Modes
local GameMode = {
    standard = 0,
    beginner = 1,
    intermediate = 2,
    expert = 3,
    custom = 4,
}

---@enum GameState.Game.States
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

local Cell = Board.Cell

local tile_to_state = Board.tile_to_state

local state_to_tile = Board.state_to_tile

local tile = _G.TILE

--============================================================================
---@class Gamestate.Game.Data
local data = {}

local mouse = love.mouse
local lgx = love.graphics
local on_mobile = _G.TARGET == "Android" or _G.TARGET == "iOS"
local controller = JM.ControllerManager.P1
local imgs

local function position_is_inside_board(x, y)
    local board = data.board
    return x >= 0 and x <= board.width * tile and y >= 0 and y <= board.height * tile and
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

    local width, height
    if self.board then
        width = self.board.width
        height = self.board.height
    end

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
            data.timer.x = cam_game.viewport_w + 20
            data.timer.y = 16
        end

        if width and height then
            local cam = cam_game
            local z = cam.viewport_h / (height * tile)
            cam:set_zoom(z)
            cam:set_position(-math.abs((width * tile) - cam.viewport_w / cam.scale) / 2, 0)
        end

        if data.bt_click then
            data.bt_click:set_position(cam_game.viewport_w + 20, 110)
        end

        if data.bt_main then
            data.bt_main:set_position(cam_game.viewport_w + 20, data.bt_click.bottom + 12)
        end

        if data.bt_zoom_in then
            data.bt_zoom_in:set_position(cam_game.viewport_x + cam_game.viewport_w - data.bt_zoom_in.w - 4,
                cam_game.viewport_y + cam_game.viewport_h)
        end

        if data.bt_zoom_out then
            data.bt_zoom_out:set_position(data.bt_zoom_in.x - data.bt_zoom_out.w - 8, data.bt_zoom_in.y)
        end
    else
        cam_gui:set_viewport(
            State.screen_w * 0,
            State.screen_h * 0,
            State.screen_w * 1,
            State.screen_h
        )

        local tw = 9
        local th = 16

        local w = tw * tile
        local sc = (State.screen_w - 8) / w
        local h = th * tile
        local x = (State.screen_w - w) / 2
        local y = tile * 2.5
        cam_game:set_viewport(
            4,
            y,
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
            data.timer.x = cam_gui.viewport_w - (11 * 6) - 6 - 4 --- 64 - 16 - 8
            data.timer.y = 16
        end

        if data.bt_click then
            data.bt_click:set_position(
                cam_gui.viewport_w - data.bt_click.w - tile * 2,
                cam_game.viewport_y + cam_game.viewport_h + tile
            )
        end

        if data.bt_main then
            local r = cam_gui.viewport_h - (cam_game.viewport_y + cam_game.viewport_h)

            data.bt_main:set_position(
                cam_gui.viewport_w / 2 - data.bt_main.w / 2,
                cam_game.viewport_y + cam_game.viewport_h + r / 2 - data.bt_main.h / 2
            )
        end

        if data.bt_zoom_in then
            data.bt_zoom_in:set_position(cam_game.viewport_x + cam_game.viewport_w - data.bt_zoom_in.w - 4,
                cam_game.viewport_y + cam_game.viewport_h + 2)
        end

        if data.bt_zoom_out then
            data.bt_zoom_out:set_position(data.bt_zoom_in.x - data.bt_zoom_out.w - 16, data.bt_zoom_in.y)
        end
        -- end
    end
    data.orientation = orientation
end
--============================================================================

function State:__get_data__()
    return data
end

---@alias Gamestate.Game.SaveData {continue:number, time:number, gamemode:GameState.Game.Modes}

---@return Gamestate.Game.SaveData
function data:get_save_data()
    return {
        continue = self.continue,
        time = self.timer.time_in_sec,
        gamemode = self.gamemode,
    }
end

---@alias GameState.Game.LoadData {board:Board.SaveData, game:Gamestate.Game.SaveData}

function data:save_game()
    local save_data = Loader.ser.pack {
        board = self.board:get_save_data(),
        game = self:get_save_data(),
    }

    return Loader:savexp(save_data, "save.dat")
end

---@return GameState.Game.LoadData|nil
function data:load_game()
    local dir = "save.dat"
    if love.filesystem.getInfo(dir) then
        return Loader.ser.unpack(Loader.loadxp(dir))
    end
end

---@type JM.Font.Font
local font_panel

---@type JM.Font.Font
local font_panel2

---@type JM.Font.Font
local pixel_font

---@type JM.Font.Font
local font_mini

local function load()
    Timer:load()
    Board:load()
    imgs = imgs or {
        ["button_main"] = love.graphics.newImage("data/img/main_button.png"),
    }

    local glyphs = "1234567890-:null:"

    font_panel = font_panel or JM.FontGenerator:new {
        name = "panel",
        font_size = 24,
        dir = "data/img/font_panel.png",
        glyphs = glyphs,
        min_filter = "linear",
        max_filter = "nearest",
        word_space = 3,
    }
    font_panel:set_color(Utils:get_rgba())
    font_panel:set_font_size(font_panel.__ref_height)

    font_panel2 = font_panel2 or JM.FontGenerator:new {
        name = "panel2",
        font_size = 24,
        dir = "data/img/font_panel_14.png",
        glyphs = glyphs,
        min_filter = "linear",
        max_filter = "nearest",
        word_space = 3,
    }
    font_panel2:set_color(Utils:get_rgba())
    font_panel2:set_font_size(font_panel2.__ref_height)

    pixel_font = pixel_font or JM.FontGenerator:new {
        name            = "pixel",
        font_size       = 24,
        dir             = "/data/img/my_pixel_font-Sheet.png",
        glyphs          = [[AÀÁÃÄÂaàáãäâBbCcÇçDdEÈÉÊËeèéêëFfGgHhIÌÍÎÏiìíîïJjKkLlMmNnOÒÓÕÔÖoòóõôöPpQqRrSsTtUÙÚÛÜuùúûüVvWwXxYyZz0123456789!?@#$%^&*()<>{}:[]:mult::div::cpy:+-_=¬'"¹²³°ºª\/.:dots:;,:dash:|¢£:blk_bar::arw_fr::arw_bk::arw_up::arw_dw::bt_a::bt_b::bt_x::bt_y::star::heart::circle:]],
        min_filter      = "linear",
        max_filter      = "nearest",
        character_space = 0,
        word_space      = 5,
        line_space      = 4,
    }
    pixel_font:set_color(Utils:get_rgba())
    pixel_font:set_font_size(pixel_font.__ref_height)

    font_mini = font_mini or JM.FontGenerator:new {
        name = "pixel mini",
        dir = "/data/img/pixel_font_mini-Sheet.png",
        glyphs = [[abcdefghijklmnopqrstuvwxyz0123456789-_.:dots::+:square::blk_bar::heart:()[]{}:arw_fr::arw_bk::arw_up::arw_dw::dash:|,;!?]],
        min_filter = 'linear',
        max_filter = 'nearest',
        character_space = 0,
        word_space = 4,
        line_space = 3,
    }
    font_mini:set_color(Utils:get_rgba())
    font_mini:set_font_size(font_mini.__ref_height)
end

local function finish()
    Timer:finish()
    Board:finish()
end

local MIN_SCALE_TO_LOW_RES = 0.3

---@param args GameState.Game.LoadData|nil
local function init(args)
    data:change_orientation(State.screen_h > State.screen_w and "portrait" or "landscape")

    data.world = JM.Physics:newWorld {
        tile = tile,
        cellsize = tile * 4,
    }
    JM.GameObject:init_state(State, data.world)

    State.game_objects = {}

    -- local save_data = data:load_game()

    data.board = Board:new(args and args.board)

    local game_data = args and args.game

    data.continue = game_data and game_data.continue or 2
    data.gamemode = game_data and game_data.gamemode or GameMode.standard
    data.time_click = 0.0
    data.pressing = false
    data.touches_ids = {}
    data.n_touches = 0
    data.gamestate = GameStates.playing
    data.click_state = ClickState.reveal
    data.direction_x = 0
    data.direction_y = 0
    data.allow_move_board = true
    mouse.setVisible(true)

    State:set_color(0.5, 0.5, 0.5, 1)

    local cam = cam_game --State.camera

    local off = Utils:round(data.board.width / 8 * 15)
    cam:set_bounds(-tile * off,
        data.board.width * tile + tile * off,
        -tile * off,
        data.board.height * tile + tile * off)

    cam:set_position(0, 0)
    cam.scale = 1
    cam.min_zoom = 0.015
    cam.max_zoom = 2
    cam:keep_on_bounds()

    data.timer = Timer:new(game_data and game_data.time)
    data.timer:lock()
    data.timer:set_font(font_panel2)
    State:add_object(data.timer)

    data.container = JM.GUI.Container:new {
        x = 0, y = 0,
        w = 2000, h = 2000,
        -- scene = State,
        -- on_focus = true,
    }

    data.bt_click = JM.GUI.Button:new {
        x = 20, y = 20, w = 32, h = 32, on_focus = true,
        text = "click",
    }
    data.bt_click:on_event("mousepressed", function()
        data.click_state = data.click_state == ClickState.reveal and ClickState.flag or ClickState.reveal
    end)

    data.bt_main = JM.GUI.Button:new {
        x = 0, y = 0, w = tile * 3, h = tile * 3, on_focus = true, text = "main"
    }

    data.bt_main:on_event("mousepressed", function()
        if data.continue > 0 and data.gamestate == GameStates.dead then
            data.board:revive()
            data:set_state(GameStates.resume)
        else
            -- local save = data:load_game()
            State:init()
        end
    end)

    ---@diagnostic disable-next-line: inject-field
    data.bt_main.__custom_draw__ = function(self)
        local img = imgs["button_main"]
        lgx.draw(img, self.x, self.y, 0, 1, 1, 0, 0)
    end

    data.bt_zoom_in = JM.GUI.Button:new {
        x = 100, y = 64, w = 16, h = 16, on_focus = true, text = "zi"
    }

    data.bt_zoom_in:on_event("mousepressed", function()
        cam_game:set_focus(cam_game.viewport_w * 0.5, cam_game.viewport_h * 0.5)
        ---@diagnostic disable-next-line: undefined-field
        State:wheelmoved(0, 1, true)
    end)

    data.bt_zoom_out = JM.GUI.Button:new {
        x = 100, y = 64, w = 16, h = 16, on_focus = true, text = "zo"
    }

    data.bt_zoom_out:on_event("mousepressed", function()
        cam_game:set_focus(cam_game.viewport_w * 0.5, cam_game.viewport_h * 0.5)
        ---@diagnostic disable-next-line: undefined-field
        State:wheelmoved(0, -1, true)
    end)

    data.container:add(data.bt_click)
    data.container:add(data.bt_main)
    data.container:add(data.bt_zoom_in)
    data.container:add(data.bt_zoom_out)

    data:change_orientation(State.screen_h > State.screen_w and "portrait" or "landscape")
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
        -- data.board:revive()
        data:save_game()
    elseif key == 't' then
        data:load_game()
    end

    if key == 'u' then
        data.continue = 0
        data.board:reveal_game()
    end
end

local function keyreleased(key)

end

function data:set_state(state)
    if state == self.gamestate then return false end
    self.gamestate = state

    if state == GameStates.victory then
        self.board:victory()
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
        self.continue = self.continue - 1
        self:set_state(GameStates.playing)
        ---
    end
    return true
end

local function mousepressed(x, y, button, istouch, presses, mx, my, __is_touch__)
    -- local on_mobile = _G.TARGET == "Android"
    local px, py = State:get_mouse_position(cam_buttons)
    if __is_touch__ then
        px = mx or px
        py = my or py
    end

    data.container:mousepressed(px, py, button, istouch, presses)

    if istouch or data.gamestate ~= GameStates.playing then
        return
    end

    if not mx or not my then
        mx, my = State:get_mouse_position(cam_game)
    end

    local board = data.board
    board:update_cell_position(mx, my)

    local is_inside_board = position_is_inside_board(mx, my)

    data.pressing = true
    if not is_inside_board or button > 2 then return end

    board:mousepressed(x, y, button, __is_touch__)
end

local function mousereleased(x, y, button, istouch, presses, mx, my, __is_touch__)
    data.moving = false

    local px, py = State:get_mouse_position(cam_buttons)
    if __is_touch__ then
        px = mx or px
        py = my or py
    end
    data.container:mousereleased(px, py, button, istouch, presses)

    if istouch or data.gamestate ~= GameStates.playing then return end

    if not mx or not my then
        mx, my = State:get_mouse_position(cam_game)
    end

    local is_inside_board = position_is_inside_board(mx, my)
    local board = data.board

    local px = board.cell_x * tile
    local py = board.cell_y * tile
    local id = board.tilemap:get_id(px, py)
    local state = tile_to_state[id]

    local allow_click = data.time_click < 0.5 and data.pressing

    if board.first_click and is_inside_board and button == 1
        and state ~= Cell.flag
        and allow_click
        and not board.chording
    then
        board:build(board.cell_y * board.width + board.cell_x)
        data.timer:unlock()
    end

    local index = board.cell_y * board.width + board.cell_x
    local prev_state = board.state[index]
    local r = board:mousereleased(x, y, button, is_inside_board, allow_click)
    local pos_state = board.state[index]

    if r == -1 then
        data:set_state(GameStates.dead)
    elseif r == 1 then
        data:set_state(GameStates.victory)
    end

    if data.pressing and button <= 2 then
        data.pressing = false
        data.time_click = 0.0
    end

    if not board.first_click and data.timer.__lock and is_inside_board
        -- and (allow_click or board.chording)
        and (pos_state ~= prev_state or r == 2)
        and data.gamestate == GameStates.playing
    then
        data.timer:unlock()
    end
end

local function mousemoved(x, y, dx, dy, istouch, mouseIsDown1, mouseIsDown2, mx, my, __is_touch__)
    if istouch then return end

    local reset_spritebatch = false
    local cam = cam_game --State.camera

    if not mx or not my then
        mx, my = State:get_mouse_position(cam_game)
    end

    local is_inside_board = position_is_inside_board(mx, my)
    local board = data.board
    board:update_cell_position(mx, my)


    if ((dx and math.abs(dx) > 1) or (dy and math.abs(dy) > 1))
        and data.allow_move_board
        and (mouseIsDown1 or (not __is_touch__ and mouse.isDown(1)))
        and (not board.chording or __is_touch__)
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


    if board.chording then
        if not is_inside_board then
            board:unpress_neighbor(board.last_cell_x, board.last_cell_y)
            board:unpress_neighbor(board.cell_x, board.cell_y)
            reset_spritebatch = true
        else
            board:unpress_neighbor(board.last_cell_x, board.last_cell_y)
            board:press_neighbor(board.cell_x, board.cell_y)
            reset_spritebatch = true
        end
    elseif not is_inside_board then
        reset_spritebatch = board:unpress_cell(board.last_cell_x, board.last_cell_y) or reset_spritebatch

        ---
    elseif data.pressing then
        local px = board.last_cell_x * tile
        local py = board.last_cell_y * tile

        local id = board.tilemap:get_id(px, py)
        local last_state = tile_to_state[id]

        if (last_state == Cell.press)
            or (mouseIsDown1 or mouse.isDown(1)
                or mouseIsDown2 or mouse.isDown(2))
        then
            reset_spritebatch = board:unpress_cell(board.last_cell_x, board.last_cell_y) or reset_spritebatch

            reset_spritebatch = board:press_cell(board.cell_x, board.cell_y) or reset_spritebatch

            data.moving = true
        end
    end

    board.last_cell_x = board.cell_x
    board.last_cell_y = board.cell_y


    if reset_spritebatch then
        board.tilemap:reset_spritebatch()
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

        if not data.allow_move_board then
            cam_game:set_focus(cam_game.viewport_w / 2, cam_game.viewport_h / 2)
        end
        cam:set_zoom(zoom)
    end

    local minscale = MIN_SCALE_TO_LOW_RES
    local board = data.board

    if cam.scale < minscale then
        board.tilemap:change_img(board.low_tileset_img)
    else
        board.tilemap:change_img(board.full_tileset_img)
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

        return mousepressed(mx, my, bt, nil, nil, mx, my, true)
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
        return mousereleased(mx, my, bt, nil, nil, mx, my, true)
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
            mousemoved(mx, my, dx, dy, nil, true, nil, mx, my, true)
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
    -- local controller = JM.ControllerManager.P1
    local Button = controller.Button

    local board = data.board
    local mx, my = board.cell_x * tile, board.cell_y * tile

    if controller:pressed(Button.A, joystick, button) then
        local index = board.cell_y * board.width + board.cell_x

        local bt = board.grid[index] >= 0
            and board.state[index] == Cell.uncover
            and 2 or 1
        mousepressed(mx, my, bt, nil, nil, mx, my)
        ---
    elseif controller:pressed(Button.B, joystick, button) then
        local id = board.number_tilemap:get_id(mx, my)

        if id == 10 or id == 9
            or tile_to_state[board.tilemap:get_id(mx, my)] == Cell.flag
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
        local id = board.number_tilemap:get_id(mx, my)

        if tile_to_state[board.tilemap:get_id(mx, my)] == Cell.flag
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
    -- local controller = JM.ControllerManager.P1
    local Button = controller.Button

    local board = data.board
    local mx, my = board.cell_x * tile, board.cell_y * tile

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

end

local function resize(w, h)
    -- local on_mobile = _G.TARGET == "Android"
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
            dw, dh = 398, 224 --485
        end
    end

    State:change_game_screen(dw, dh)

    data:change_orientation(State.screen_h > State.screen_w and "portrait" or "landscape")
end


local function update(dt)
    State:update_game_objects(dt)
    data.container:update(dt)

    local board = data.board

    if data.pressing then
        local mx, my = board.cell_x * tile, board.cell_y * tile
        if _G.TARGET == "Android" and data.time_click >= 0.5
            and not data.moving
            and position_is_inside_board(State:get_mouse_position(cam_game))
            and not board.chording
        then
            local id = board.tilemap:get_id(mx, my)

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
    -- local controller = JM.ControllerManager.P1
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
        local mx, my = board.cell_x * tile, board.cell_y * tile

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
            if board.cell_x * tile + tile > cam.x + cam.viewport_w / cam.scale then
                board.cell_x = Utils:clamp(math.floor((cam.x + cam.viewport_w / cam.scale - tile) / tile), 0,
                    board.width - 1)
            end
        elseif axis_right_x > 0.5 then
            cam:move(speed * dt)
            if board.cell_x * tile < cam_game.x then
                board.cell_x = Utils:clamp(math.floor((cam.x + tile) / tile), 0, board.width - 1)
            end
        end

        local axis_right_y = controller:pressing(Button.right_stick_y)
        if axis_right_y < -0.5 then
            cam:move(0, -speed * dt)
            if board.cell_y * tile + tile > cam.y + cam.viewport_h / cam.scale then
                board.cell_y = Utils:clamp(math.floor((cam.y + cam.viewport_h / cam.scale - tile) / tile), 0,
                    board.height - 1)
            end
        elseif axis_right_y > 0.5 then
            cam:move(0, speed * dt)
            if board.cell_y * tile < cam_game.y then
                board.cell_y = Utils:clamp(math.floor((cam.y + tile) / tile), 0, board.height - 1)
            end
        end

        if data.direction_x == 0 then
            controller.time_delay_button[Button.left_stick_x] = 0.5
        else
            controller.time_delay_button[Button.left_stick_x] = 0.1
        end

        local axis_x = controller:pressing_time(Button.left_stick_x)

        if axis_x and axis_x > 0 then
            board.cell_x = Utils:clamp(board.cell_x + 1, 0, board.width - 1)

            data.direction_x = 1
            local mx, my = board.cell_x * tile, board.cell_y * tile
            mousemoved(nil, nil, nil, nil, nil, controller:pressing(Button.A), controller:pressing(Button.B), mx, my)
            ---
        elseif axis_x and axis_x < 0 then
            board.cell_x = Utils:clamp(board.cell_x - 1, 0, board.width - 1)

            data.direction_x = -1
            local mx, my = board.cell_x * tile, board.cell_y * tile
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
            board.cell_y = Utils:clamp(board.cell_y + 1, 0, board.height - 1)
            data.direction_y = 1
            local mx, my = board.cell_x * tile, board.cell_y * tile
            mousemoved(nil, nil, nil, nil, nil, controller:pressing(Button.A), controller:pressing(Button.B), mx, my)
            ---
        elseif axis_y and axis_y < 0 then
            board.cell_y = Utils:clamp(board.cell_y - 1, 0, board.height - 1)
            data.direction_y = -1
            local mx, my = board.cell_x * tile, board.cell_y * tile
            mousemoved(nil, nil, nil, nil, nil, controller:pressing(Button.A), controller:pressing(Button.B), mx, my)
            ---
        elseif controller:pressing(Button.left_stick_y) == 0 then
            data.direction_y = 0
        end
    end
end

local layer_main = {
    ---@param cam JM.Camera.Camera
    draw = function(self, cam)
        -- if cam == data.cam2 then return end
        if cam ~= cam_game then return end

        lgx.setColor(179 / 255, 185 / 255, 209 / 255)
        lgx.rectangle("fill", cam:get_viewport_in_world_coord())

        local font = JM.Font.current

        local board = data.board
        board:draw()

        local px = board.cell_x * tile
        local py = board.cell_y * tile
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

        local board = data.board

        if data.orientation == "landscape" then
            local flags = board.mines - board.flags
            font_panel:print((flags > -10 and ":null:" or "") .. string.format("%02d", flags),
                cam_game.viewport_w + 20,
                16 + font_panel.__ref_height + 4
            )

            local r = data.gamestate == GameStates.playing and "playing"
            r = not r and data.gamestate == GameStates.dead and "dead" or r
            r = not r and data.gamestate == GameStates.victory and "victory" or r
            r = not r and "Error" or r

            font:print(tostring(r), cam_game.viewport_w + 20, 64)

            r = data.click_state == ClickState.reveal and "reveal"
            r = not r and data.click_state == ClickState.flag and "flag" or r
            font:print(tostring(r), cam_game.viewport_w + 20, 64 + 16)

            font:print(tostring(data.continue), cam_game.viewport_w + 20, 64 + 32)

            ---
        else
            font_panel2:print(string.format("%02d", board.mines - board.flags), 4, data.timer.y)

            local r = data.gamestate == GameStates.playing and "playing"
            r = not r and data.gamestate == GameStates.dead and "dead" or r
            r = not r and data.gamestate == GameStates.victory and "victory" or r
            r = not r and "Error" or r
            font:printf(tostring(r), 20, cam_game.viewport_y + cam_game.viewport_h)

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

        local font = JM.Font.current

        -- font_panel2:print("123:null:0912-00", 100, 100)

        pixel_font:printx(
            "Casa Çasaç AA <effect=spooky>DafFa</effect> GgfFjiJHhiI PpajiqapQ Wwyq 0123456789Zz\n O <effect=ghost>Rato</effect> roeu a :mult: roupa do rei de (Roma)^1*3\n :div:astha\n :cpy:João Moreira:¬ +-@TMJ_por_JM \n (^-^) ¬¬ 'oi'" ..
            ' - " 2¹²³2C° 1º\\/. tentei:dots: tempo;\n :dash: Oi! (|a) laranja ¢q£ªº¬ âmbar ÂMBAR Ëkë Î Ï ï<effect=flickering, speed=0.8>:blk_bar:</effect>\n Ô Ö õôö ÛÜ úùûü\n <effect=flickering>:arw_fr:</effect no-space>Teste:arw_bk: <effect=wave, speed=2><color,0,0,0,1>Press :bt_a: to <color>charge</color no-space>.</effect> :bt_b: too works :bt_x: :bt_y: :: :star: :heart: :circle:Bomb,;hein?',
            2, 32, nil, "left")

        font_mini:print(
            ":square:testando, ai; !?-- 012345+6789-_ aff:dots: tem ::blk_bar: cora:heart:[(as)]{}\n:arw_fr:oi:arw_bk: :arw_up: :arw_dw: |:dash:espera",
            10,
            200)
        -- font_panel:push()
        -- font_panel:set_color(Utils:get_rgba())
        -- font_panel:print("123-", 32, 32)
        -- font_panel:pop()
        -- if data.save_table then
        --     font:print(tostring(data.save_table.width), 64, 64)
        -- end
        local limits = love.graphics.getSystemLimits()
        pixel_font:print(tostring(limits.texturesize), 32, 2)
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
