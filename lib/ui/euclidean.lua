--- EuclideanUI
-- @classmod EuclideanUI

local ControlSpec = require 'controlspec'
local UI = require "ui"
local Label = require("cyrene/lib/ui/util/label")
local UIState = require('cyrene/lib/ui/util/devices')
local Euclidean = require('cyrene/lib/euclidean')

local MAX_PATTERN_LENGTH = 32
local NUM_TRACKS = 7

local active_hi_level = 15
local active_lo_level = 6
local inactive_hi_level = 3
local inactive_lo_level = 1
local CLICK_DURATION = 0.7

local EuclideanUI = {}

function EuclideanUI:new(sequencer)
  i = {}
  setmetatable(i, self)
  self.__index = self

  i.trigs_labels = {}
  i.length_labels = {}
  i.disabled_labels = {}
  local y_start = 4
  local y_distance_between = 8
  for track=1,NUM_TRACKS do
    local y = y_start+(y_distance_between*track)
    i.trigs_labels[track] = Label.new({x=2, y=y})
    i.length_labels[track] = Label.new({x=13, y=y})
    i.disabled_labels[track] = Label.new({x=24, y=y, level=0, text="x"})
  end
  i._track = 1
  i._alt_key_down_time = nil
  i._cached_euclideans = nil
  i._sequencer = sequencer

  return i
end

function EuclideanUI:enc(n, delta, sequencer)
  local param_id_prefix = self.param_id_prefix_for_track(self._track)
  if self._alt_key_down_time then
    self._alt_action_taken = true
    if n == 2 then
      params:delta(param_id_prefix.."_euclidean_rotation", delta)
    elseif n == 3 then
      params:delta(param_id_prefix.."_euclidean_enabled", delta)
    end
  else
    if n == 2 then
      params:delta(param_id_prefix.."_euclidean_trigs", delta)
    elseif n == 3 then
      params:delta(param_id_prefix.."_euclidean_length", delta)
    end
  end
end

function EuclideanUI:key(n, z, sequencer)
  local direction = 0
  if n == 2 then
    if z == 1 then
      self._alt_key_down_time = util.time()
      return
    end

    -- Key up on K2 after an alt action was taken, or even just after a longer held time, counts as nothing
    if self._alt_key_down_time then
      local key_down_duration = util.time() - self._alt_key_down_time
      self._alt_key_down_time = nil
      if self._alt_action_taken or key_down_duration > CLICK_DURATION then
        self._alt_action_taken = false
        return
      end
    end

    direction = -1
  elseif n == 3 and z == 1 then
    direction = 1
  end
  self._track = (self._track + direction + NUM_TRACKS - 1) % NUM_TRACKS + 1
  self:_update_label_levels()
end

function EuclideanUI:_update_ui_from_params()
  self:_update_label_levels()
  self._cached_euclideans = nil
  for track=1,NUM_TRACKS do
    local param_id_prefix = self.param_id_prefix_for_track(track)
    self.trigs_labels[track].text = params:get(param_id_prefix.."_euclidean_trigs")
    self.length_labels[track].text = params:get(param_id_prefix.."_euclidean_length")
  end
end

local markers_start_x = 29
local x_distance_between = math.floor((125-markers_start_x)/MAX_PATTERN_LENGTH)
function EuclideanUI:redraw(sequencer)
  if UIState.params_dirty then
    self:_update_ui_from_params()
  end
  if self._cached_euclideans == nil then
    self:_recompute_cached_euclideans()
  end
  for track=1,NUM_TRACKS do
    local param_id_prefix = self.param_id_prefix_for_track(track)
    local enabled = params:get(param_id_prefix.."_euclidean_enabled") == 2
    self.trigs_labels[track]:redraw()
    self.length_labels[track]:redraw()
    self.disabled_labels[track]:redraw()
    local track_length = params:get(param_id_prefix.."_euclidean_length")
    local y = self.trigs_labels[track].y
    local level
    if track == self._track then
      level = enabled and active_hi_level or active_lo_level
    else
      level = enabled and inactive_hi_level or inactive_lo_level
    end
    screen.level(level)
    for x=1,track_length do
      screen.move(x*x_distance_between + markers_start_x, y)
      local has_trigger = self._cached_euclideans[track][x]
      screen.line_rel(0, has_trigger and -6 or -2)
      screen.stroke()
    end
  end
end

function EuclideanUI.param_id_prefix_for_track(track)
  return "cy_"..track
end

function EuclideanUI:_update_label_levels()
  for track=1,NUM_TRACKS do
    local param_id_prefix = self.param_id_prefix_for_track(track)
    local enabled = params:get(param_id_prefix.."_euclidean_enabled") == 2
    if track == self._track then
      self.trigs_labels[track].level = enabled and active_hi_level or active_lo_level
      self.length_labels[track].level = enabled and active_hi_level or active_lo_level
      self.disabled_labels[track].level = not enabled and active_hi_level or 0
    else
      self.trigs_labels[track].level = enabled and inactive_hi_level or inactive_lo_level
      self.length_labels[track].level = enabled and inactive_hi_level or inactive_lo_level
      self.disabled_labels[track].level = not enabled and inactive_hi_level or 0
    end
  end
  UIState.screen_dirty = true
end

function EuclideanUI:_recompute_cached_euclideans()
  local result = {}
  for track=1,NUM_TRACKS do
    local param_id_prefix = self.param_id_prefix_for_track(track)
    local trigs = params:get(param_id_prefix.."_euclidean_trigs")
    local length = params:get(param_id_prefix.."_euclidean_length")
    local rotation = params:get(param_id_prefix.."_euclidean_rotation")
    local pattern = Euclidean.get_pattern(trigs, length, rotation)
    table.insert(result, pattern)
  end
  self._cached_euclideans = result
end

function EuclideanUI:_update_sequencer(track)
  if not self._sequencer then return end
  local param_id_prefix = self.param_id_prefix_for_track(track)
  local enabled = params:get(param_id_prefix.."_euclidean_enabled") == 2
  if not enabled then return end
  self._sequencer:recompute_euclidean_for_track(track)
end

return EuclideanUI
