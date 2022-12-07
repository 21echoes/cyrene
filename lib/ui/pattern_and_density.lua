--- PatternAndDensityUI
-- @classmod PatternAndDensityUI

local ControlSpec = require 'controlspec'
local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')

local active_hi_level = 15
local active_lo_level = 6
local inactive_hi_level = 3
local inactive_lo_level = 1

local PatternAndDensityUI = {}

function PatternAndDensityUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  local font_size = 16
  i.kick_title_label = Label.new({x=66, y=14, text="KIK", font_size=font_size})
  i.kick_val_label = Label.new({x=66, y=28, font_size=font_size})
  i.snare_title_label = Label.new({x=96, y=14, text="SNR", font_size=font_size})
  i.snare_val_label = Label.new({x=96, y=28, font_size=font_size})
  i.hat_title_label = Label.new({x=66, y=49, text="HAT", font_size=font_size})
  i.hat_val_label = Label.new({x=66, y=63, font_size=font_size})
  i.chaos_title_label = Label.new({x=96, y=49, text=" !?", font_size=font_size})
  i.chaos_val_label = Label.new({x=96, y=63, font_size=font_size})

  i._section = 0
  i:_update_active_section()

  return i
end

function PatternAndDensityUI:enc(n, delta, sequencer)
  if self._section == 0 then
    if n == 2 then
      params:delta('cy_grids_pattern_x', delta)
    elseif n == 3 then
      params:delta('cy_grids_pattern_y', delta)
    end
  elseif self._section == 1 then
    if n == 2 then
      params:delta('cy_1_density', delta)
    elseif n == 3 then
      params:delta('cy_2_density', delta)
    end
  elseif self._section == 2 then
    if n == 2 then
      params:delta('cy_3_density', delta)
    elseif n == 3 then
      params:delta('cy_pattern_chaos', delta)
    end
  end
end

function PatternAndDensityUI:key(n, z, sequencer)
  if (n == 2 or n == 3) and z == 1 then
    local direction = n == 2 and -1 or 1
    self._section = (self._section + direction + 3) % 3
    self:_update_active_section()
  end
end

function PatternAndDensityUI:_update_ui_from_params()
  self.kick_val_label.text = params:get("cy_1_density")
  self.snare_val_label.text = params:get("cy_2_density")
  self.hat_val_label.text = params:get("cy_3_density")
  self.chaos_val_label.text = params:get("cy_pattern_chaos")
end

function PatternAndDensityUI:redraw(sequencer)
  if UIState.params_dirty then
    self:_update_ui_from_params()
  end

  screen.level(self._section == 0 and 15 or 4)
  screen.line_width(2)
  screen.rect(1, 1, 62, 62)
  screen.stroke()
  local x = util.round(60 * params:get("cy_grids_pattern_x") / 255) + 2
  local y = util.round(60 * params:get("cy_grids_pattern_y") / 255) + 2
  screen.line_width(1)
  screen.circle(x, y, 2)
  screen.fill()
  screen.level(15)

  self.kick_title_label:redraw()
  self.kick_val_label:redraw()
  self.snare_title_label:redraw()
  self.snare_val_label:redraw()
  self.hat_title_label:redraw()
  self.hat_val_label:redraw()
  self.chaos_title_label:redraw()
  self.chaos_val_label:redraw()
end

function PatternAndDensityUI:_update_active_section()
  self.kick_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.kick_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  self.snare_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.snare_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  self.hat_title_label.level = self._section == 2 and active_lo_level or inactive_lo_level
  self.hat_val_label.level = self._section == 2 and active_hi_level or inactive_hi_level
  self.chaos_title_label.level = self._section == 2 and active_lo_level or inactive_lo_level
  self.chaos_val_label.level = self._section == 2 and active_hi_level or inactive_hi_level
  UIState.screen_dirty = true
end

return PatternAndDensityUI
