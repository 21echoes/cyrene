--- PlaybackUI
-- @classmod PlaybackUI

local UI = require "ui"
local Label = include("lib/ui/util/label")
local UIState = include('lib/ui/util/devices')
local TapTempo = include("lib/ui/util/tap_tempo")
local MidiOut = include('lib/midi_out')

local hi_level = 15
local mid_level = 6
local lo_level = 4
local CLICK_DURATION = 0.7

local PlaybackUI = {}

function PlaybackUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  local font_size = 16
  i.stop_label = Label.new({x=4, y=31, text="STOP", font_size=font_size})
  i.play_label = Label.new({x=68, y=31, text="PLAY", font_size=font_size})
  i.playpos_label = Label.new({x=68, y=49, level=hi_level, font_size=font_size})

  return i
end

function PlaybackUI:add_params(arcify)
end

function PlaybackUI:add_params_for_track(track, arcify)
end

function PlaybackUI:enc(n, delta, sequencer)
end

function PlaybackUI:key(n, z, sequencer)
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

function PlaybackUI:redraw(sequencer)
  if UIState.show_event_indicator then
    screen.level(lo_level)
    screen.rect(122, 1, 5, 5)
    screen.fill()
  end

  self.stop_label.level = sequencer.playing and lo_level or hi_level
  self.stop_label:redraw()
  self.play_label.level = sequencer.playing and hi_level or lo_level
  self.play_label:redraw()
  if sequencer.playing then
    self.playpos_label.text = sequencer.playpos+1
    self.playpos_label:redraw()
  end
end

return PlaybackUI
