-- Cyrene, a drummer in a box
--
-- E1 controls page
--
-- Landing page:
-- E2 controls tempo
-- E3 controls swing
-- K2+E2 controls volume
-- K2 stops playback
-- K3 resumes playback
-- K2 while stopped
--  resets to beat 1
--
-- Pattern & Density page:
-- K2 & K3 switch sections
-- E2 & E3 change values
--
-- Grid (optional):
-- Rows are tracks
-- First 3: kick, snare, hat
-- Columns are beats
-- Key toggles trigger
-- Last row changes
--  playback position
--
-- Change samples and fx
--  via the params menu
--
--
-- Adapted from Grids
--   by Emilie Gillet
-- and Step, by @jah
--
--
-- v0.9.0 @21echoes

engine.name = 'Ack'

local Ack = require 'ack/lib/ack'
local UI = require 'ui'
local Sequencer = include('lib/sequencer')
local DetailsUI = include('lib/ui/details')
local PatternAndDensityUI = include('lib/ui/pattern_and_density')
local UIState = include('lib/ui/util/devices')

local launch_version
local current_version = "0.9.0"

local TRIG_LEVEL = 15
local PLAYPOS_LEVEL = 7
local CLEAR_LEVEL = 0

-- TODO: these are duplicated in sequencer.lua
local MAX_GRID_WIDTH = 16
local HEIGHT = 8

local sequencer
local pages
local pages_table
local ui_refresh_metro

local function init_params()
  params:add {
    id="cyrene_version",
    name="Cyrene Version",
    type="text",
  }
  params:hide(params.lookup["cyrene_version"])
  sequencer:add_params()
  for i, page in ipairs(pages_table) do
    pages_table[i]:add_params()
  end
  params:add_separator()
  Ack.add_params()

  local is_first_launch = not sequencer:has_pattern_file()
  if is_first_launch then
    local bd_path = _path.dust .. "audio/common/808/808-BD.wav"
    if util.file_exists(bd_path) then
      params:set("1_sample", bd_path)
      params:set("1_vol", -10.0)
    end
    local sd_path = _path.dust .. "audio/common/808/808-SD.wav"
    if util.file_exists(sd_path) then
      params:set("2_sample", sd_path)
      params:set("2_vol", -20.0)
    end
    local ch_path = _path.dust .. "audio/common/808/808-CH.wav"
    if util.file_exists(ch_path) then
      params:set("3_sample", ch_path)
      params:set("3_vol", -15.0)
    end
  end
end

local function init_60_fps_ui_refresh_metro()
  ui_refresh_metro = metro.init()
  ui_refresh_metro.event = UIState.refresh
  ui_refresh_metro.time = 1/60
  ui_refresh_metro:start()
end

local function init_ui()
  pages = UI.Pages.new(1, #pages_table)

  UIState.init_arc {
    device = arc.connect(),
    delta_callback = function(n, delta)
      if n == 1 then
        local val = params:get_raw("tempo")
        params:set_raw("tempo", val+delta/500)
      elseif n == 2 then
        local val = params:get_raw("swing_amount")
        params:set_raw("swing_amount", val+delta/500)
      end
    end,
    refresh_callback = function(my_arc)
      my_arc:all(0)
      my_arc:led(1, util.round(params:get_raw("tempo")*64), 15)
      my_arc:led(2, util.round(params:get_raw("swing_amount")*64), 15)
    end
  }

  UIState.init_grid {
    device = grid.connect(),
    key_callback = function(x, y, state)
      if state == 1 then
        if y == 8 then
          sequencer.queued_playpos = x-1
          UIState.screen_dirty = true
        else
          sequencer:set_trig(
            params:get("pattern"),
            x,
            y,
            sequencer:trig_level(params:get("pattern"), x, y) == 0 and 255 or 0
          )
          UIState.grid_dirty = true
        end
      end
      UIState.flash_event()
    end,
    refresh_callback = function(my_grid)
      local function refresh_grid_button(x, y)
        if y == 8 then
          if x-1 == sequencer.playpos then
            my_grid:led(x, y, PLAYPOS_LEVEL)
          else
            my_grid:led(x, y, CLEAR_LEVEL)
          end
        else
          local trig_level = sequencer:trig_level(params:get("pattern"), x, y)
          local grid_trig_level = math.ceil((trig_level / 255) * TRIG_LEVEL)
          if grid_trig_level > 0 then
            my_grid:led(x, y, grid_trig_level)
          elseif x-1 == sequencer.playpos then
            my_grid:led(x, y, PLAYPOS_LEVEL)
          else
            my_grid:led(x, y, CLEAR_LEVEL)
          end
        end
      end

      local function refresh_grid_column(x)
        for y=1,HEIGHT do
          refresh_grid_button(x, y)
        end
      end

      local function refresh_grid()
        for x=1,MAX_GRID_WIDTH do
          refresh_grid_column(x)
        end
      end

      refresh_grid()
    end,
    width_changed_callback = function(new_width)
      sequencer:set_pattern_length(new_width)
    end
  }

  UIState.init_screen {
    refresh_callback = function()
      redraw()
    end
  }

  init_60_fps_ui_refresh_metro()
end

function init()
  math.randomseed(os.time())
  -- Once we care about comparing launch and current versions, use this:
  -- _check_launch_version()

  sequencer = Sequencer:new()
  pages_table = {
    DetailsUI:new(),
    PatternAndDensityUI:new(),
  }

  init_params()
  init_ui()

  sequencer:initialize()
  sequencer:start()

  params:read()
  params:set("cyrene_version", current_version)
  params:bang()
end

function cleanup()
  params:write()

  sequencer:save_patterns()

  if my_grid.device then
    my_grid:all(0)
    my_grid:refresh()
  end

  metro.free(ui_refresh_metro.id)
  ui_refresh_metro = nil
  -- for i, page in ipairs(pages_table) do
  --   pages_table[i]:cleanup()
  --   pages_table[i] = nil
  -- end
  pages_table = nil
  pages = nil
end

local function current_page()
  return pages_table[pages.index]
end

function redraw()
  screen.clear()
  pages:redraw()
  current_page():redraw(sequencer)
  screen.update()
end

function enc(n, delta)
  if n == 1 then
    -- E1 changes page
    pages:set_index_delta(util.clamp(delta, -1, 1), false)
    -- current_page():enter()
    UIState.screen_dirty = true
  else
    -- Other encoders are routed to the current page's class
    current_page():enc(n, delta, sequencer)
  end
end

function key(n, z)
  -- All key presses are routed to the current page's class.
  current_page():key(n, z, sequencer)
end

-- Version management

function _check_launch_version()
  local filename = norns.state.data .. norns.state.shortname
  filename = filename .. "-" .. string.format("%02d",1) .. ".pset"
  local fd = io.open(filename, "r")
  if fd then
    io.close(fd)
    for line in io.lines(filename) do
      if not util.string_starts(line, "--") then
        local id, value = string.match(line, "(\".-\")%s*:%s*(.*)")
        if id and value then
          if id == "\"cyrene_version\"" then
            launch_version = value
          end
        end
      end
    end
  end
end

function _version_gt(a, b)
  if type(b) ~= "string" then return true end
  local a_table = a:match("([^.]+).([^.]+).([^.]+)")
  local b_table = b:match("([^.]+).([^.]+).([^.]+)")
  if b_table == nil or #b_table ~= 3 then return true end
  if a_table == nil or #a_table ~= 3 then return false end
  for i, v in ipairs(a) do
    if v > b[i] then return true end
    if v < b[i] then return false end
  end
  return false
end
