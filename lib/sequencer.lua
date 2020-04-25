local ControlSpec = require 'controlspec'
local UI = include('lib/ui/util/devices')

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

function Sequencer:set_trig(patternno, x, y, value)
  self.trigs[patternno][y][x] = value
end

function Sequencer:trig_is_set(patternno, x, y)
  return self.trigs[patternno][y][x]
end

function Sequencer:_init_trigs()
  for patternno=1,NUM_PATTERNS do
    self.trigs[patternno] = {}
    for y=1,HEIGHT do
      self.trigs[patternno][y] = {}
      for x=1,MAX_GRID_WIDTH do
        -- TODO: port the values in the array and on disk to 255-based for probabilities
        self.trigs[patternno][y][x] = false
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
        local int
        if self:trig_is_set(patternno, x, y) then
          int = 1
        else
          int = 0
        end
        io.write(int .. "\n")
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
      for y=1,HEIGHT do
        for x=1,MAX_GRID_WIDTH do
          self:set_trig(patternno, x, y, tonumber(io.read()) == 1)
        end
      end
    end
    io.close(fd)
  end
end

function Sequencer:tick()
  if queued_playpos and params:get("cut_quant") == 1 then
    self.ticks_to_next = 0
  end

  if (not self.ticks_to_next) or self.ticks_to_next == 0 then
    local previous_playpos = self.playpos
    if self.queued_playpos then
      self.playpos = self.queued_playpos
      self.queued_playpos = nil
    else
      self.playpos = (self.playpos + 1) % self:get_pattern_length()
    end
    local ts = {}
    for y=1,7 do
      if self:trig_is_set(params:get("pattern"), self.playpos+1, y) then
        ts[y] = 1
      else
        ts[y] = 0
      end
    end
    engine.multiTrig(ts[1], ts[2], ts[3], ts[4], ts[5], ts[6], ts[7], 0)

    if previous_playpos ~= -1 then
      UI.grid_dirty = true
    end
    if self.playpos ~= -1 then
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
