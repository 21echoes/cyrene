--- DensityUI
-- @classmod DensityUI

local ControlSpec = require 'controlspec'
local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')

local DensityUI = {}

function DensityUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  i.kick_density_dial = UI.Dial.new(16, 34, 22, 128, 0, 255, 1)
  i.snare_density_dial = UI.Dial.new(53, 34, 22, 128, 0, 255, 1)
  i.hat_density_dial = UI.Dial.new(90, 34, 22, 128, 0, 255, 1)

  i._alt_key_down_time = nil

  return i
end

function DensityUI:add_params()
  params:add {
    type="control",
    id="kick_density",
    name="Kick Density",
    -- TODO: what is WARP_LIN
    controlspec=ControlSpec.new(0, 255, ControlSpec.WARP_LIN, 1, 128, ""),
    action=function(value)
      self.kick_density_dial:set_value(value)
      UIState.screen_dirty = true
    end
  }
  params:add {
    type="control",
    id="snare_density",
    name="Snare Density",
    controlspec=ControlSpec.new(0, 255, ControlSpec.WARP_LIN, 1, 128, ""),
    action=function(value)
      self.snare_density_dial:set_value(value)
      UIState.screen_dirty = true
    end
  }
  params:add {
    type="control",
    id="hat_density",
    name="Hi-Hat Density",
    controlspec=ControlSpec.new(0, 255, ControlSpec.WARP_LIN, 1, 128, ""),
    action=function(value)
      self.hat_density_dial:set_value(value)
      UIState.screen_dirty = true
    end
  }
end

function DensityUI:enc(n, delta, sequencer)
  if self._alt_key_down_time then
    params:delta('hat_density', delta)
  else
    if n == 2 then
      params:delta('kick_density', delta)
    elseif n == 3 then
      params:delta('snare_density', delta)
    end
  end
end

function DensityUI:key(n, z, sequencer)
  if n == 2 then
    if z == 1 then
      self._alt_key_down_time = util.time()
    else
      self._alt_key_down_time = nil
    end
  end
end

function DensityUI:redraw(sequencer)
  self.kick_density_dial:redraw()
  self.snare_density_dial:redraw()
  self.hat_density_dial:redraw()
end

return DensityUI
