--- MoreDensityUI
-- @classmod MoreDensityUI

local ControlSpec = require 'controlspec'
local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')

local active_hi_level = 15
local active_lo_level = 4
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

function MoreDensityUI:add_params_for_track(track, arcify)
  -- PatternAndDensityUI handles tracks 1-3
  if track < 4 then return end
  local param_id = "track"..track.."_density"
  local param_name = track..": Density"
  local val_label = self["track"..track.."_val_label"]
  params:add {
    type="number",
    id=param_id,
    name=param_name,
    min=0,
    max=100,
    default=50,
    formatter=function(param) return param.value .. "%" end,
    action=function(value)
      val_label.text = value
      UIState.screen_dirty = true
    end
  }
  arcify:register(param_id)
end

function MoreDensityUI:enc(n, delta, sequencer)
  if self._section == 0 then
    if n == 2 then
      params:delta('track4_density', delta)
    elseif n == 3 then
      params:delta('track5_density', delta)
    end
  elseif self._section == 1 then
    if n == 2 then
      params:delta('track6_density', delta)
    elseif n == 3 then
      params:delta('track7_density', delta)
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

function MoreDensityUI:redraw(sequencer)
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
end

return MoreDensityUI
