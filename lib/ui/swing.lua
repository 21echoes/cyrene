--- SwingUI
-- @classmod SwingUI

local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')

local active_hi_level = 15
local active_lo_level = 6
local inactive_hi_level = 3
local inactive_lo_level = 1
local font_size = 16

local SwingUI = {}

function SwingUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  local x1 = 4
  local x2 = 68
  local y1 = 14
  local y2 = 49
  local val_title_gap = font_size - 2
  i.type_title_label = Label.new({x=x1, y=y1, text="SWING", font_size=font_size})
  i.type_val_label = Label.new({x=x1, y=y1+val_title_gap, font_size=font_size})
  i.amt_title_label = Label.new({x=x2, y=y1, text="AMNT", font_size=font_size})
  i.amt_val_label = Label.new({x=x2, y=y1+val_title_gap, font_size=font_size})
  i.basis_title_label = Label.new({x=x1, y=y2, text="BASIS", font_size=font_size})
  i.basis_val_label = Label.new({x=x1, y=y2+val_title_gap, font_size=font_size})
  i.feel_title_label = Label.new({x=x2, y=y2, text="FEEL", font_size=font_size})
  i.feel_val_label = Label.new({x=x2, y=y2+val_title_gap, font_size=font_size})

  i._cached_basis = 2
  i._section = 0
  i:_update_active_section()

  return i
end

function SwingUI:_get_is_simple_swing()
  return params:get("cy_shuffle_basis") == 1
end

function SwingUI:enc(n, delta, sequencer)
  if self._section == 0 then
    if n == 2 then
      if delta < 0 then
        if params:get("cy_shuffle_basis") ~= 1 then
          self._cached_basis = params:get("cy_shuffle_basis")
        end
        params:set("cy_shuffle_basis", 1)
      elseif params:get("cy_shuffle_basis") == 1 then
        params:set("cy_shuffle_basis", self._cached_basis)
      end
    elseif n == 3 then
      if self:_get_is_simple_swing() then
        params:delta("cy_swing_amount", delta)
      end
    end
  elseif self._section == 1 then
    if params:get("cy_shuffle_basis") > 1 then
      if n == 2 then
        params:delta("cy_shuffle_basis", delta)
        -- Don't let section 1 take us back to simple shuffle
        if params:get("cy_shuffle_basis") == 1 then
          params:set("cy_shuffle_basis", 2)
        end
      elseif n == 3 then
        params:delta("cy_shuffle_feel", delta)
      end
    end
  end
  UIState.screen_dirty = true
end

function SwingUI:key(n, z, sequencer)
  if (n == 2 and z == 0) or (n == 3 and z == 1) then
    local direction = n == 2 and -1 or 1
    self._section = (self._section + direction + 2) % 2
    if self:_get_is_simple_swing() then
      self._section = 0
    end
    self:_update_active_section()
  end
end

local shuffle_basis_names = {
  "STRAIGHT",
  "9",
  "7",
  "5",
  "6",
  "8??",
  "9??",
}
local shuffle_feel_names = {
  "DRUNK",
  "SMOOTH",
  "HEAVY",
  "CLAVE"
}

function SwingUI:_update_ui_from_params()
  local is_simple_swing = self:_get_is_simple_swing()

  self.type_val_label.text = is_simple_swing and "PCT" or "TUPLET"
  self.amt_val_label.text = util.round(params:get("cy_swing_amount"), 1) .. "%"
  self.basis_val_label.text = shuffle_basis_names[params:get("cy_shuffle_basis")]
  self.feel_val_label.text = shuffle_feel_names[params:get("cy_shuffle_feel")]
end

function SwingUI:redraw(sequencer)
  if UIState.params_dirty then
    self:_update_ui_from_params()
  end

  local is_simple_swing = self:_get_is_simple_swing()

  self.type_title_label:redraw()
  self.type_val_label:redraw()

  self.amt_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.amt_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  if not is_simple_swing then
    self.amt_title_label.level = 0
    self.amt_val_label.level = 0
  end
  self.amt_title_label:redraw()
  self.amt_val_label:redraw()

  self.basis_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.basis_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  if is_simple_swing then
    self.basis_title_label.level = 0
    self.basis_val_label.level = 0
  end
  self.basis_title_label:redraw()
  self.basis_val_label:redraw()

  self.feel_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.feel_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  if is_simple_swing then
    self.feel_title_label.level = 0
    self.feel_val_label.level = 0
  end
  self.feel_title_label:redraw()
  self.feel_val_label:redraw()
end

function SwingUI:_update_active_section()
  self.type_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.type_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.amt_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.amt_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.basis_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.basis_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  self.feel_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.feel_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  UIState.screen_dirty = true
end

return SwingUI
