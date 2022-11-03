--- SwingUI
-- @classmod SwingUI

local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')

local active_hi_level = 15
local active_lo_level = 5
local inactive_hi_level = 3
local inactive_lo_level = 1
local CLICK_DURATION = 0.7
local font_size = 16
local med_font_size = 16
local small_font_size = 8

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
  i.swing_type_title_label = Label.new({x=x1, y=y1, text="SWING", font_size=font_size})
  i.swing_type_val_label = Label.new({x=x1, y=y1+val_title_gap, font_size=font_size})
  i.swing_amt_title_label = Label.new({x=x2, y=y1, text="AMNT", font_size=font_size})
  i.swing_amt_val_label = Label.new({x=x2, y=y1+val_title_gap, font_size=font_size})
  i.swing_feel_title_label = Label.new({x=x2, y=y2, text="FEEL", font_size=font_size})
  i.swing_feel_val_label = Label.new({x=x2, y=y2+val_title_gap, font_size=font_size})

  i._cached_basis = 2
  i._section = 0
  i:_update_active_section()

  return i
end

function SwingUI:add_params(arcify)
  local default_clock_source_action = params:lookup_param("clock_source").action
  params:set_action("clock_source", function(val)
    UIState.screen_dirty = true
    default_clock_source_action(val)
  end)
  -- TODO: move swing params in here
end

function SwingUI:add_params_for_track(track, arcify)
end

function SwingUI:enc(n, delta, sequencer)
  if self._section == 0 then
    if n == 2 then
      if delta < 0 then
        if params:get("shuffle_basis") ~= 1 then
          self._cached_basis = params:get("shuffle_basis")
        end
        params:set("shuffle_basis", 1)
      elseif params:get("shuffle_basis") == 1 then
        params:set("shuffle_basis", self._cached_basis)
      end
    elseif n == 3 then
      local is_simple_swing = params:get("shuffle_basis") == 1
      if is_simple_swing then
        params:delta('swing_amount', delta)
      else
        params:delta('shuffle_basis', delta)
        -- Don't let enc 3 go to simple shuffle
        if params:get("shuffle_basis") == 1 then
          params:set("shuffle_basis", 2)
        end
      end
    end
  elseif self._section == 1 then
    if params:get("shuffle_basis") > 1 then
      params:delta("shuffle_feel", delta)
    end
  end
  UIState.screen_dirty = true
end

function SwingUI:key(n, z, sequencer)
  if (n == 2 and z == 0) or (n == 3 and z == 1) then
    local direction = n == 2 and -1 or 1
    self._section = (self._section + direction + 2) % 2
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

function SwingUI:redraw(sequencer)
  local is_simple_swing = params:get("shuffle_basis") == 1
  self.swing_type_title_label:redraw()
  self.swing_type_val_label.text = is_simple_swing and "PCT" or "TUPLET"
  self.swing_type_val_label:redraw()
  self.swing_amt_title_label.text = is_simple_swing and "AMNT" or "BASIS"
  self.swing_amt_title_label:redraw()
  if is_simple_swing then
    self.swing_amt_val_label.text = util.round(params:get("swing_amount"), 1) .. "%"
    self.swing_amt_val_label.font_size = font_size
  else
    self.swing_amt_val_label.text = shuffle_basis_names[params:get("shuffle_basis")]
    self.swing_amt_val_label.font_size = med_font_size
  end
  self.swing_amt_val_label:redraw()

  self.swing_feel_val_label.text = shuffle_feel_names[params:get("shuffle_feel")]
  self.swing_feel_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.swing_feel_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  if is_simple_swing then
    self.swing_feel_title_label.level = 0
    self.swing_feel_val_label.level = 0
  end
  self.swing_feel_title_label:redraw()
  self.swing_feel_val_label:redraw()
end

function SwingUI:_update_active_section()
  self.swing_type_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.swing_type_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.swing_amt_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.swing_amt_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.swing_feel_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.swing_feel_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  UIState.screen_dirty = true
end

return SwingUI
