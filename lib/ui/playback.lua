--- PlaybackUI
-- @classmod PlaybackUI

local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')
local TapTempo = include("lib/ui/util/tap_tempo")
local MidiOut = include('lib/midi_out')

local active_hi_level = 15
local active_lo_level = 6
local inactive_hi_level = 3
local inactive_lo_level = 1
local CLICK_DURATION = 0.7

local PlaybackUI = {}

function PlaybackUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  local font_size = 16
  local small_font_size = 8
  local x1 = 4
  local x2 = 68
  local y1 = 14
  local val_title_gap = font_size - 2
  i.level_title_label = Label.new({x=x1, y=y1, text="LEVEL", level=5, font_size=font_size})
  i.level_val_label = Label.new({x=x1, y=y1+val_title_gap, level=15, font_size=font_size})
  i.bpm_title_label = Label.new({x=x2, y=y1, text="BPM", level=5, font_size=font_size})
  i.bpm_val_label = Label.new({x=x2, y=y1+val_title_gap, level=15, font_size=font_size})
  i.bpm_control_disabled_label = Label.new({x=x2+30, y=y1+val_title_gap, text="(EXT)", font_size=small_font_size})

  i.stop_label = Label.new({x=0, y=63, text="STOP", font_size=font_size})
  i.play_label = Label.new({x=45, y=63, text="PLAY", font_size=font_size})
  i.playpos_label = Label.new({x=99, y=63, level=active_hi_level, font_size=font_size})

  i._tap_tempo = TapTempo.new()

  return i
end

function PlaybackUI:enc(n, delta, sequencer)
  if n == 2 then
    params:delta('output_level', delta)
  elseif n == 3 then
    if params:get("clock_source") == 1 then
      params:delta("clock_tempo", delta)
    end
  end
end

function PlaybackUI:key(n, z, sequencer)
  local tempo, short_circuit_value = self._tap_tempo:key(n, z)
  if tempo and params:get("clock_source") == 1 then
    params:set("clock_tempo", tempo)
    UIState.screen_dirty = true
  end
  if short_circuit_value ~= nil then
    return short_circuit_value
  end

  if n == 2 then
    if sequencer.playing == false then
      params:set("cy_reset", 1)
      UIState.grid_dirty = true
    else
      params:set("cy_play", 0)
      MidiOut:stop()
    end
  elseif n == 3 and z == 1 then
    if sequencer.playing == false then
      if sequencer.playpos == -1 and sequencer.queued_playpos == 0 then
        MidiOut:start_at_beginning()
      else
        MidiOut:continue()
      end
      params:set("cy_play", 1)
    end
  end
  UIState.screen_dirty = true
end

function PlaybackUI:redraw(sequencer)
  if UIState.show_event_indicator then
    screen.level(active_lo_level)
    screen.rect(122, 1, 5, 5)
    screen.fill()
  end

  self.level_title_label:redraw()
  self.level_val_label.text = util.round(params:get_raw("output_level")/0.707*100,1)
  self.level_val_label:redraw()

  self.bpm_title_label:redraw()
  self.bpm_val_label.text = util.round(params:get("clock_tempo"), 1)
  self.bpm_val_label.level = (params:get("clock_source") ~= 1) and inactive_hi_level or active_hi_level
  self.bpm_val_label:redraw()
  self.bpm_control_disabled_label.level = (params:get("clock_source") ~= 1) and inactive_hi_level or 0
  self.bpm_control_disabled_label:redraw()

  self.stop_label.level = sequencer.playing and active_lo_level or active_hi_level
  self.stop_label:redraw()
  self.play_label.level = sequencer.playing and active_hi_level or active_lo_level
  self.play_label:redraw()
  if sequencer.playing then
    self.playpos_label.text = sequencer.playpos+1
    self.playpos_label:redraw()
  end
end

return PlaybackUI
