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
-- Bottom right is alt,
--  hold & click bottom left
--  to change page
--
-- Change samples, fx, etc
--  via the params menu
--
--
-- Adapted from Grids
--   by Emilie Gillet
-- and Step, by @jah
--
--
-- v1.0.1 @21echoes

engine.name = 'Ack'

local Ack = require 'ack/lib/ack'
local UI = require 'ui'
local Sequencer = include('lib/sequencer')
local DetailsUI = include('lib/ui/details')
local PatternAndDensityUI = include('lib/ui/pattern_and_density')
local UIState = include('lib/ui/util/devices')
local GridUI = include('lib/ui/grid')

local launch_version
local current_version = "0.9.1"

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
    _set_sample(1, "audio/common/808/808-BD.wav", -10.0)
    _set_sample(2, "audio/common/808/808-SD.wav", -20.0)
    _set_sample(3, "audio/common/808/808-CH.wav", -15.0)
    _set_sample(4, "audio/common/808/808-OH.wav", -18.0)
    _set_sample(5, "audio/common/808/808-MA.wav", -12.0)
    _set_sample(6, "audio/common/808/808-RS.wav", -17.0)
    _set_sample(7, "audio/common/808/808-HC.wav", -20.0)
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
        if params:get("clock_source") == 1 then
          local val = params:get_raw("clock_tempo")
          params:set("clock_tempo", val+delta/500)
        end
      elseif n == 2 then
        local val = params:get_raw("swing_amount")
        params:set_raw("swing_amount", val+delta/500)
      end
    end,
    refresh_callback = function(my_arc)
      my_arc:all(0)
      my_arc:led(1, util.round(params:get("clock_tempo")*64), 15)
      my_arc:led(2, util.round(params:get_raw("swing_amount")*64), 15)
    end
  }

  GridUI.init(sequencer)

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

  GridUI.cleanup()

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

function clock.transport.start()
  if sequencer then
    sequencer:start()
  end
end

function clock.transport.stop()
  if sequencer then
    sequencer:stop()
  end
end

function _set_sample(track, path, volume)
  local full_path = _path.dust .. path
  if util.file_exists(full_path) then
    params:set(track .. "_sample", full_path)
    params:set(track .. "_vol", volume)
  end
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
