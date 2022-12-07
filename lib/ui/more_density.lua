--- MoreDensityUI
-- @classmod MoreDensityUI

local ControlSpec = require 'controlspec'
local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')

local active_hi_level = 15
local active_lo_level = 6
local inactive_hi_level = 3
local inactive_lo_level = 1

local MoreDensityUI = {}

function MoreDensityUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  local font_size = 16
  local x1 = 4
  local x2 = 68
  local y1 = 14
  local y2 = 49
  local val_title_gap = font_size - 2
  -- this relies implicitly on NUM_TRACKS=7
  i.track4_title_label = Label.new({x=x1, y=y1, text="TRK 4", font_size=font_size})
  i.track4_val_label = Label.new({x=x1, y=y1+val_title_gap, font_size=font_size})
  i.track5_title_label = Label.new({x=x2, y=y1, text="TRK 5", font_size=font_size})
  i.track5_val_label = Label.new({x=x2, y=y1+val_title_gap, font_size=font_size})
  i.track6_title_label = Label.new({x=x1, y=y2, text="TRK 6", font_size=font_size})
  i.track6_val_label = Label.new({x=x1, y=y2+val_title_gap, font_size=font_size})
  i.track7_title_label = Label.new({x=x2, y=y2, text="TRK 7", font_size=font_size})
  i.track7_val_label = Label.new({x=x2, y=y2+val_title_gap, font_size=font_size})

  i._section = 0
  i:_update_active_section()

  return i
end

function MoreDensityUI:enc(n, delta, sequencer)
  if self._section == 0 then
    if n == 2 then
      params:delta('cy_4_density', delta)
    elseif n == 3 then
      params:delta('cy_5_density', delta)
    end
  elseif self._section == 1 then
    if n == 2 then
      params:delta('cy_6_density', delta)
    elseif n == 3 then
      params:delta('cy_7_density', delta)
    end
  end
end

function MoreDensityUI:key(n, z, sequencer)
  if (n == 2 or n == 3) and z == 1 then
    local direction = n == 2 and -1 or 1
    self._section = (self._section + direction + 2) % 2
    self:_update_active_section()
  end
end

function MoreDensityUI:_update_ui_from_params()
  -- This relates to how this UI has hard-coded NUM_TRACKS=7
  for track=4,7 do
    local val_label = self["track"..track.."_val_label"]
    val_label.text = params:get("cy_"..track.."_density")
  end
end

function MoreDensityUI:redraw(sequencer)
  if UIState.params_dirty then
    self:_update_ui_from_params()
  end

  self.track4_title_label:redraw()
  self.track4_val_label:redraw()
  self.track5_title_label:redraw()
  self.track5_val_label:redraw()
  self.track6_title_label:redraw()
  self.track6_val_label:redraw()
  self.track7_title_label:redraw()
  self.track7_val_label:redraw()
end

function MoreDensityUI:_update_active_section()
  self.track4_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.track4_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.track5_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.track5_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.track6_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.track6_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  self.track7_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.track7_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  UIState.screen_dirty = true
end

return MoreDensityUI
