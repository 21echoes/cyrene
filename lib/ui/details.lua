--- DetailsUI
-- @classmod DetailsUI

local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')
local TapTempo = include("lib/ui/util/tap_tempo")
local MidiOut = include('lib/midi_out')

local active_hi_level = 15
local active_lo_level = 5
local inactive_hi_level = 3
local inactive_lo_level = 1
local CLICK_DURATION = 0.7
local font_size = 16
local med_font_size = 16
local small_font_size = 8

local DetailsUI = {}

function DetailsUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  local x1 = 4
  local x2 = 68
  local y1 = 14
  local y2 = 49
  local val_title_gap = font_size - 2
  i.level_title_label = Label.new({x=x1, y=y1, text="LEVEL", font_size=font_size})
  i.level_val_label = Label.new({x=x1, y=y1+val_title_gap, font_size=font_size})
  i.bpm_title_label = Label.new({x=x2, y=y1, text="BPM", font_size=font_size})
  i.bpm_val_label = Label.new({x=x2, y=y1+val_title_gap, font_size=font_size})
  i.bpm_control_disabled_label = Label.new({x=x2+30, y=y1+val_title_gap, text="(EXT)", font_size=small_font_size})
  i.swing_type_title_label = Label.new({x=x1, y=y2, text="SWING", font_size=font_size})
  i.swing_type_val_label = Label.new({x=x1, y=y2+val_title_gap, font_size=font_size})
  i.swing_amt_title_label = Label.new({x=x2, y=y2, text="AMNT", font_size=font_size})
  i.swing_amt_val_label = Label.new({x=x2, y=y2+val_title_gap, font_size=font_size})

  i._tap_tempo = TapTempo.new()

  i._section = 0
  i:_update_active_section()

  return i
end

function DetailsUI:add_params(arcify)
  local default_clock_source_action = params:lookup_param("clock_source").action
  params:set_action("clock_source", function(val)
    UIState.screen_dirty = true
    default_clock_source_action(val)
  end)
  -- TODO: move tempo and swing in here
end

function DetailsUI:add_params_for_track(track, arcify)
end

function DetailsUI:enc(n, delta, sequencer)
  if self._section == 0 then
    if n == 2 then
      params:delta('output_level', delta)
    elseif n == 3 then
      if params:get("clock_source") == 1 then
        params:delta("clock_tempo", delta)
      end
    end
  elseif self._section == 1 then
    if n == 2 then
      params:delta('shuffle_basis', delta)
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
  end
  UIState.screen_dirty = true
end

function DetailsUI:key(n, z, sequencer)
  local tempo, short_circuit_value = self._tap_tempo:key(n, z)
  if tempo and params:get("clock_source") == 1 then
    params:set("clock_tempo", tempo)
    UIState.screen_dirty = true
  end
  if short_circuit_value ~= nil then
    return short_circuit_value
  end

  if (n == 2 and z == 0) or (n == 3 and z == 1) then
    local direction = n == 2 and -1 or 1
    self._section = (self._section + direction + 2) % 2
    self:_update_active_section()
  end
end

local shuffle_basis_names = {
  "STRAIGHT",
  "7",
  "9",
  "5",
  "6",
  "8??",
  "9??",
}

function DetailsUI:redraw(sequencer)
  self.level_title_label:redraw()
  self.level_val_label.text = util.round(params:get_raw("output_level")/0.707*100,1)
  self.level_val_label:redraw()

  self.bpm_title_label:redraw()
  self.bpm_val_label.text = util.round(params:get("clock_tempo"), 1)
  if self._section == 0 then
    self.bpm_val_label.level = (params:get("clock_source") ~= 1) and inactive_hi_level or active_hi_level
  else
    self.bpm_val_label.level = inactive_hi_level
  end
  self.bpm_val_label:redraw()
  self.bpm_control_disabled_label.level = (params:get("clock_source") ~= 1) and inactive_hi_level or 0
  self.bpm_control_disabled_label:redraw()

  local is_simple_swing = params:get("shuffle_basis") == 1
  print("is_simple_swing "..(is_simple_swing and "yes" or "no")..", shuffle_basis "..params:get("shuffle_basis"))
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
end

function DetailsUI:_update_active_section()
  self.level_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.level_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.bpm_title_label.level = self._section == 0 and active_lo_level or inactive_lo_level
  self.bpm_val_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.bpm_control_disabled_label.level = self._section == 0 and active_hi_level or inactive_hi_level
  self.swing_type_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.swing_type_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  self.swing_amt_title_label.level = self._section == 1 and active_lo_level or inactive_lo_level
  self.swing_amt_val_label.level = self._section == 1 and active_hi_level or inactive_hi_level
  UIState.screen_dirty = true
end

return DetailsUI
