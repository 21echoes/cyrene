--- DetailsUI
-- @classmod DetailsUI

local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')
local TapTempo = include("lib/ui/util/tap_tempo")
local MidiOut = include('lib/midi_out')

local hi_level = 15
local mid_level = 6
local lo_level = 4
local CLICK_DURATION = 0.7

local DetailsUI = {}

function DetailsUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  local font_size = 16
  local enc1_x = 0
  local enc1_y = 12
  i.enc1_title_label = Label.new({x=enc1_x, y=enc1_y, level=lo_level, text="LEVEL", font_size=font_size})
  i.enc1_val_label = Label.new({x=enc1_x+45, y=enc1_y, level=hi_level, font_size=font_size})
  local enc2_x = 16
  local enc2_y = 32
  i.enc2_title_label = Label.new({x=enc2_x, y=enc2_y, level=lo_level, text="BPM", font_size=font_size})
  i.enc2_val_label = Label.new({x=enc2_x, y=enc2_y+12, font_size=font_size})
  i.clock_disabled_label = Label.new({x=0, y=enc2_y+12, text="EXT: ", font_size=8})
  local enc3_x = 61
  local enc3_y = 32
  i.enc3_title_label = Label.new({x=enc3_x, y=enc3_y, level=lo_level, text="SWING", font_size=font_size})
  i.enc3_val_label = Label.new({x=enc3_x, y=enc3_y+12, level=hi_level, font_size=font_size})
  i.stop_label = Label.new({x=0, y=63, text="STOP", font_size=font_size})
  i.play_label = Label.new({x=45, y=63, text="PLAY", font_size=font_size})
  i.playpos_label = Label.new({x=99, y=63, level=hi_level, font_size=font_size})

  i._tap_tempo = TapTempo.new()

  return i
end

function DetailsUI:add_params()
  local default_clock_source_action = params:lookup_param("clock_source").action
  params:set_action("clock_source", function(val)
    UIState.screen_dirty = true
    default_clock_source_action(val)
  end)
  -- TODO: move tempo and swing in here
end

function DetailsUI:add_params_for_track(track)
end

function DetailsUI:enc(n, delta, sequencer)
  -- We're using tap_tempo:is_in_tap_tempo_mode as our general "alt mode"
  if self._tap_tempo:is_in_tap_tempo_mode() then
    mix:delta("output", delta)
    UIState.screen_dirty = true
  else
    if n == 2 then
      if params:get("clock_source") == 1 then
        params:delta("clock_tempo", delta)
      end
    elseif n == 3 then
      params:delta("swing_amount", delta)
    end
  end
end

function DetailsUI:key(n, z, sequencer)
  local tempo, short_circuit_value = self._tap_tempo:key(n, z)
  if tempo and params:get("clock_source") == 1 then
    params:set("clock_tempo", tempo)
  end
  if short_circuit_value ~= nil then
    return short_circuit_value
  end

  if n == 2 then
    if sequencer.playing == false then
      sequencer:move_to_start()
      UIState.grid_dirty = true
    else
      sequencer:stop()
      MidiOut:stop()
    end
  elseif n == 3 and z == 1 then
    if sequencer.playing == false then
      if sequencer.playpos == -1 and sequencer.queued_playpos == 0 then
        MidiOut:start_at_beginning()
      else
        MidiOut:continue()
      end
      sequencer:start()
    end
  end
  UIState.screen_dirty = true
end

function DetailsUI:redraw(sequencer)
  self.enc1_title_label:redraw()
  self.enc1_val_label.text = util.round(mix:get_raw("output")*100, 1)
  self.enc1_val_label:redraw()

  if UIState.show_event_indicator then
    screen.level(lo_level)
    screen.rect(122, 1, 5, 5)
    screen.fill()
  end

  self.enc2_title_label:redraw()
  self.enc2_val_label.text = util.round(params:get("clock_tempo"), 1)
  self.enc2_val_label.level = (params:get("clock_source") ~= 1) and mid_level or hi_level
  self.enc2_val_label:redraw()
  self.clock_disabled_label.level = (params:get("clock_source") ~= 1) and mid_level or 0
  self.clock_disabled_label:redraw()

  self.enc3_title_label:redraw()
  self.enc3_val_label.text = util.round(params:get("swing_amount"), 1) .. "%"
  self.enc3_val_label:redraw()

  self.stop_label.level = sequencer.playing and lo_level or hi_level
  self.stop_label:redraw()
  self.play_label.level = sequencer.playing and hi_level or lo_level
  self.play_label:redraw()
  if sequencer.playing then
    self.playpos_label.text = sequencer.playpos+1
    self.playpos_label:redraw()
  end
end

return DetailsUI
