--- PatternUI
-- @classmod PatternUI

local ControlSpec = require 'controlspec'
local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')

local PatternUI = {}

function PatternUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  i.x_dial = UI.Dial.new(16, 12, 22, 128, 0, 255, 1)
  i.y_dial = UI.Dial.new(53, 12, 22, 128, 0, 255, 1)
  i.chaos_dial = UI.Dial.new(90, 12, 22, 128, 0, 255, 1)

  i._alt_key_down_time = nil

  return i
end

function PatternUI:add_params()
  params:add {
    type="control",
    id="grids_pattern_x",
    name="Pattern X",
    -- TODO: what is WARP_LIN
    controlspec=ControlSpec.new(0, 255, ControlSpec.WARP_LIN, 1, 0, ""),
    action=function(value)
      self.x_dial:set_value(value)
      UIState.screen_dirty = true
    end
  }
  params:add {
    type="control",
    id="grids_pattern_y",
    name="Pattern Y",
    controlspec=ControlSpec.new(0, 255, ControlSpec.WARP_LIN, 1, 0, ""),
    action=function(value)
      self.y_dial:set_value(value)
      UIState.screen_dirty = true
    end
  }
  params:add {
    type="control",
    id="pattern_chaos",
    name="Chaos",
    controlspec=ControlSpec.new(0, 255, ControlSpec.WARP_LIN, 1, 0, ""),
    action=function(value)
      self.chaos_dial:set_value(value)
      UIState.screen_dirty = true
    end
  }
end

function PatternUI:enc(n, delta, sequencer)
  if self._alt_key_down_time then
    params:delta('pattern_chaos', delta)
  else
    if n == 2 then
      params:delta('grids_pattern_x', delta)
    elseif n == 3 then
      params:delta('grids_pattern_y', delta)
    end
  end
end

function PatternUI:key(n, z, sequencer)
  if n == 2 then
    if z == 1 then
      self._alt_key_down_time = util.time()
    else
      self._alt_key_down_time = nil
    end
  end
end

function PatternUI:redraw(sequencer)
  self.x_dial:redraw()
  self.y_dial:redraw()
  self.chaos_dial:redraw()
end

return PatternUI
