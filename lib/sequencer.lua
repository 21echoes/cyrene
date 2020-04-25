local ControlSpec = require 'controlspec'
local UI = include('lib/ui/util/devices')
local DrumMap = include('lib/grids_patterns')
local tabutil = require 'tabutil'

local PATTERN_FILE = "step.data"

local NUM_PATTERNS = 99
local ppqn = 24

-- TODO: these are duplicated in coleman.lua
local MAX_GRID_WIDTH = 16
local HEIGHT = 8

local tempo_spec = ControlSpec.new(20, 300, ControlSpec.WARP_LIN, 0, 120, "BPM")
local swing_amount_spec = ControlSpec.new(0, 100, ControlSpec.WARP_LIN, 0, 0, "%")

local Sequencer = {}

function Sequencer:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  i.trigs = {}
  i:_init_trigs()
  i.playing = false
  i.playpos = -1
  i.ticks_to_next = nil
  i.queued_playpos = nil
  i.grids_x = nil
  i.grids_y = nil

  return i
end

function Sequencer:add_params()
  params:add {
    type="option",
    id="pattern_length",
    name="Pattern Length",
    options={8, 16},
    default=2
  }

  params:add {
    type="number",
    id="pattern",
    name="Pattern",
    min=1,
    max=NUM_PATTERNS,
    default=1,
    action=function()
      UI.grid_dirty = true
    end
  }

  params:add {
    type="option",
    id="cut_quant",
    name="Quantize Cutting",
    options={"No", "Yes"},
    default=1
  }

  params:add {
    type="number",
    id="beats_per_pattern",
    name="Beats Per Pattern",
    min=1,
    max=8,
    default=4,
    action=function(val) self:_update_sequencer_metro_time(val) end
  }

  params:add {
    type="control",
    id="tempo",
    name="Tempo",
    controlspec=tempo_spec,
    action=function(val)
      self:_update_sequencer_metro_time(val)
      UI.screen_dirty = true
      UI.arc_dirty = true
    end
  }

  params:add {
    type="control",
    id="swing_amount",
    name="Swing Amount",
    controlspec=swing_amount_spec,
    action=function(val)
      self:update_swing(val)
      UI.screen_dirty = true
      UI.arc_dirty = true
    end
  }
end

function Sequencer:initialize()
  self.sequencer_metro = metro.init()
  self:_init_sequencer_metro()
  self:load_patterns()
end

function Sequencer:start()
  self.playing = true
  self.sequencer_metro:start()
end

function Sequencer:move_to_start()
  self.playpos = -1
  self.queued_playpos = 0
end

function Sequencer:stop()
  self.playing = false
  self.sequencer_metro:stop()
end

function Sequencer:set_trig(patternno, step, track, value)
  self.trigs[patternno][track][step] = value
end

function Sequencer:trig_level(patternno, x, y)
  return self.trigs[patternno][y][x]
end

function Sequencer:_init_trigs()
  for patternno=1,NUM_PATTERNS do
    self.trigs[patternno] = {}
    for y=1,HEIGHT do
      self.trigs[patternno][y] = {}
      for x=1,MAX_GRID_WIDTH do
        self.trigs[patternno][y][x] = 0
      end
    end
  end
end

function Sequencer:get_pattern_length()
  if params:get("pattern_length") == 1 then
    return 8
  else
    return 16
  end
  -- TODO: Grids uses length-32 patterns
end

function Sequencer:set_pattern_length(pattern_length)
  local opt
  if pattern_length == 8 then
    opt = 1
  else
    opt = 2
  end
  params:set("pattern_length", opt)
end

function Sequencer:save_patterns()
  local fd=io.open(norns.state.data .. PATTERN_FILE,"w+")
  io.output(fd)
  for patternno=1,NUM_PATTERNS do
    for y=1,HEIGHT do
      for x=1,MAX_GRID_WIDTH do
        io.write(self:trig_level(patternno, x, y) .. "\n")
      end
    end
  end
  io.close(fd)
end

function Sequencer:load_patterns()
  local fd=io.open(norns.state.data .. PATTERN_FILE,"r")
  if fd then
    io.input(fd)
    for patternno=1,NUM_PATTERNS do
      for track=1,HEIGHT do
        for step=1,MAX_GRID_WIDTH do
          -- self:set_trig(patternno, x, y, tonumber(io.read()))
          self:set_trig(patternno, step, track, math.random(0, 255))
        end
      end
    end
    io.close(fd)
  end
end

local function u8mix(a, b, mix)
  -- Roughly equivalent to ((mix * b + (255 - mix) * a) >> 8), if this is too non-performant
  return util.round(((mix * b) + ((255 - mix) * a)) / 255)
end

function Sequencer:set_grids_xy(patternno, x, y)
  -- Short-circuit this expensive operation if there's no change
  if x == self.grids_x and y == self.grids_y then
    return
  end
  -- Chose four drum map nodes based on the first two bits of x and y
  local i = math.floor(x / 64) + 1 -- (x >> 6) + 1
  local j = math.floor(y / 64) + 1 -- (y >> 6) + 1
  local a_map = DrumMap.map[i][j]
  local b_map = DrumMap.map[i + 1][j]
  local c_map = DrumMap.map[i][j + 1]
  local d_map = DrumMap.map[i + 1][j + 1]
  for track=1,3 do
    local track_offset = ((track - 1) * DrumMap.PATTERN_LENGTH)
    for step=1,MAX_GRID_WIDTH do
      local offset = track_offset + step
      local a = a_map[offset]
      local b = b_map[offset]
      local c = c_map[offset]
      local d = d_map[offset]
      -- Crossfade between the values at the chosen drum nodes depending on the last 6 bits of x and y
      local x_xfade = (x * 4) % 256 -- x << 2
      local y_xfade = (y * 4) % 256 -- y << 2
      local trig_level = u8mix(u8mix(a, b, x_xfade), u8mix(c, d, x_xfade), y_xfade)
      self:set_trig(patternno, step, track, trig_level)
    end
  end
  self.grids_x = x
  self.grids_y = y
end

function Sequencer:tick()
  if queued_playpos and params:get("cut_quant") == 1 then
    self.ticks_to_next = 0
  end

  if (not self.ticks_to_next) or self.ticks_to_next == 0 then
    local patternno = params:get("pattern")
    -- Update the triggers to match the selected MI-Grids X and Y parameters
    self:set_grids_xy(patternno, params:get("grids_pattern_x"), params:get("grids_pattern_y"))
    local previous_playpos = self.playpos
    if self.queued_playpos then
      self.playpos = self.queued_playpos
      self.queued_playpos = nil
    else
      self.playpos = (self.playpos + 1) % self:get_pattern_length()
    end
    local ts = {}
    for y=1,7 do
      local trig_level = self:trig_level(patternno, self.playpos+1, y)
      local threshold
      if y == 1 then
        threshold = 255 - params:get("kick_density")
      elseif y == 2 then
        threshold = 255 - params:get("snare_density")
      elseif y == 3 then
        threshold = 255 - params:get("hat_density")
      else
        threshold = math.random(0, 255)
      end
      ts[y] = trig_level > threshold and 1 or 0
    end
    engine.multiTrig(ts[1], ts[2], ts[3], ts[4], ts[5], ts[6], ts[7], 0)

    if previous_playpos ~= -1 or self.playpos ~= -1 then
      UI.grid_dirty = true
    end
    if self.playpos % 2 == 0 then
      self.ticks_to_next = self.even_ppqn
    else
      self.ticks_to_next = self.odd_ppqn
    end
    UI.screen_dirty = true
  end
  self.ticks_to_next = self.ticks_to_next - 1
end

function Sequencer:_update_sequencer_metro_time()
  self.sequencer_metro.time = 60/params:get("tempo")/ppqn/params:get("beats_per_pattern")
end

function Sequencer:update_swing(swing_amount)
  local swing_ppqn = ppqn*swing_amount/100*0.75
  self.even_ppqn = util.round(ppqn+swing_ppqn)
  self.odd_ppqn = util.round(ppqn-swing_ppqn)
end

function Sequencer:_init_sequencer_metro()
  self:_update_sequencer_metro_time()
  self.sequencer_metro.event = function() self:tick() end
end

return Sequencer
