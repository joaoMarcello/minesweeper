-- local Font = _G.JM_Font
local GC = JM.GameObject

local color_white = _G.JM_Utils:get_rgba(1, 1, 1, 1)
local color_yellow = _G.JM_Utils:get_rgba(1, 1, 0, 1)

local string_format = string.format
local math_floor = math.floor

---@type JM.Font.Font
local font

---@class Timer : GameObject
local Timer = setmetatable({}, GC)
Timer.__index = Timer

---@return Timer
function Timer:new(time_in_sec)
    local obj = GC:new(320, 0, 64, 32, 50)
    setmetatable(obj, self)
    Timer.__constructor__(obj, time_in_sec)
    return obj
end

function Timer:__constructor__(time_in_sec)
    self.time_in_sec = time_in_sec or 0
    self.speed = 1.0
    self.acumulator = 0.0

    self.__lock = false

    if not font then
        font = JM:get_font()
    end
end

function Timer:init()

end

function Timer:load()
    -- local glyphs = "1234567890-"

    -- local font_panel = JM.FontGenerator:new {
    --     name = "panel",
    --     font_size = 24,
    --     dir = "data/img/font_panel.png",
    --     glyphs = glyphs,
    --     min_filter = "linear",
    --     max_filter = "nearest",
    --     word_space = 3,
    -- }
    -- font_panel:set_font_size(font_panel.__ref_height)
    -- font_panel:set_color { 1, 1, 1, 1 }
    -- font = font_panel
end

function Timer:set_font(new_font)
    font = new_font
end

function Timer:finish()

end

--===========================================================================

function Timer:time_is_up()
    return self.time_in_sec <= 0.0
end

function Timer:flick()
    local eff = self:apply_effect("flickering", { speed = 0.1, duration = 0.2 * 6 })
    self.is_flick = true
    eff:set_final_action(function()
        self:set_visible(true)
        self.is_flick = false
    end)
end

function Timer:pulse()
    local eff = self:apply_effect("pulse", { range = 0.15, speed = 0.3, duration = 0.3 * 4 })
end

function Timer:increment(value)
    value = value or 0
    self.time_in_sec = self.time_in_sec + value
    if self.time_in_sec <= 0 then self.time_in_sec = 0 end

    if value > 0 then
        self:pulse()
    end
end

function Timer:decrement(value)
    value = -math.abs(value)
    self:increment(value)
    self:flick()
end

function Timer:minute()
    return math_floor(self.time_in_sec / 60)
end

function Timer:seconds(minutes)
    minutes = minutes or self:minute()
    local sec = math_floor(self.time_in_sec - minutes * 60)
    return sec
end

function Timer:get_time()
    local minutes = self:minute()
    local seconds = self:seconds(minutes)
    local dec = (self.time_in_sec - minutes * 60 - seconds) * 10

    return minutes, seconds, dec
end

function Timer:get_time2()
    local time = self.time_in_sec * 100
    local minute = math_floor(time / 6000)
    local seconds = (time - (minute * 6000)) / 100
    seconds = math_floor(seconds)
    local dec = time - minute * 6000 - seconds * 100

    return minute, seconds, dec
end

function Timer:lock(time)
    if not self.__lock then
        self.__lock = true
    end
end

function Timer:unlock()
    if self.__lock then self.__lock = false end
end

function Timer:pause(time)
    self.__pause = time or 0.5
    self:lock()
end

function Timer:update(dt)
    GC.update(self, dt)

    if self.__pause then
        self.__pause = self.__pause - dt
        if self.__pause <= 0 then
            self.__pause = false
            self:unlock()
        end
    end

    if not self.__lock then
        self.time_in_sec = self.time_in_sec + dt
        if self.time_in_sec < 0 then self.time_in_sec = 0 end
    end
end

function Timer:my_draw()
    local min, sec, dec = self:get_time2()

    local px, py = font:print(string_format("%02d", min), self.x, self.y)
    px, py = font:print(string_format("%02d", sec), px + 4, py)
    return font:print(string_format("%02d", dec), px + 4, py)
end

function Timer:draw()
    GC.draw(self, Timer.my_draw)
end

return Timer
