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
-- More Densities page:
-- K2 & K3 switch sections
-- E2 & E3 change values
--
-- Euclidean page:
-- K2 & K3 switch track
-- E2 changes fill
-- E3 changes length
-- K2+E2 changes rotation
-- K2+E3 enables/disables
--   euclidean mode
--    (when off, changes
--     have no effect)
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
--    to change page
--  hold & click a track
--    for probability editing
--    then click next to alt
--    to go back
--
-- Crow (optional):
-- Configurable
--  via params menu
-- Outputs are gates
--  or envelopes
--  per track
-- Inputs modulate
--  selected params
--
-- Arc (optional):
-- Use the params page
-- to choose which params
-- are controled by which enc
-- Defaults:
-- E1: Tempo
-- E2: Swing
-- E3: Pattern X
-- E4: Pattern Y
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
-- v1.7.2 @21echoes
local current_version = "1.7.2"

engine.name = 'Ack'

local Ack = require 'ack/lib/ack'
local UI = require 'ui'
local Sequencer = include('lib/sequencer')
local MidiOut = include('lib/midi_out')
local DetailsUI = include('lib/ui/details')
local PatternAndDensityUI = include('lib/ui/pattern_and_density')
local MoreDensityUI = include('lib/ui/more_density')
local EuclideanUI = include('lib/ui/euclidean')
local UIState = include('lib/ui/util/devices')
local GridUI = include('lib/ui/grid')
local CrowIO = include('lib/crow_io')
local Arcify = include("lib/arcify")

local launch_version

local sequencer
local pages
local pages_table
local ui_refresh_metro
local NUM_TRACKS = 7

local arc_device = arc.connect()
local arcify = Arcify.new(arc_device, false)

local function init_params()
  params:add_separator()
  params:add {
    id="cyrene_version",
    name="Cyrene Version",
    type="text",
  }
  params:hide(params.lookup["cyrene_version"])
  sequencer:add_params(arcify)
  -- Only the first 2 pages have any generic params
  pages_table[1]:add_params(arcify)
  pages_table[2]:add_params(arcify)
  for track=1,NUM_TRACKS do
    local group_name = "Track "..track
    if track == 1 then group_name = "Kick"
    elseif track == 2 then group_name = "Snare"
    elseif track == 3 then group_name = "Hi-Hat"
    end
    params:add_group(group_name, 27)
    -- All the pages together add 5 params per track
    for i, page in ipairs(pages_table) do
      pages_table[i]:add_params_for_track(track, arcify)
    end
    Ack.add_channel_params(track) -- 22 params
    -- all params except the file are arcifyed
    arcify:register(track.."_start_pos")
    arcify:register(track.."_end_pos")
    arcify:register(track.."_loop")
    arcify:register(track.."_loop_point")
    arcify:register(track.."_speed")
    arcify:register(track.."_vol")
    arcify:register(track.."_vol_env_atk")
    arcify:register(track.."_vol_env_rel")
    arcify:register(track.."_pan")
    arcify:register(track.."_filter_cutoff")
    arcify:register(track.."_filter_res")
    arcify:register(track.."_filter_mode")
    arcify:register(track.."_filter_env_atk")
    arcify:register(track.."_filter_env_rel")
    arcify:register(track.."_filter_env_mod")
    arcify:register(track.."_sample_rate")
    arcify:register(track.."_bit_depth")
    arcify:register(track.."_dist")
    arcify:register(track.."_in_mutegroup")
    arcify:register(track.."_delay_send")
    arcify:register(track.."_reverb_send")
  end
  params:add_group("Effects", 6)
  Ack.add_effects_params() -- 6 params
  arcify:register("delay_time")
  arcify:register("delay_feedback")
  arcify:register("delay_level")
  arcify:register("reverb_room_size")
  arcify:register("reverb_damp")
  arcify:register("reverb_level")
  MidiOut:add_params(arcify)
  CrowIO:add_params(arcify)
  arcify:add_params()

  local is_first_launch = not sequencer:has_pattern_file()
  if is_first_launch then
    _set_sample(1, "audio/x0x/808/808-BD.wav", -10.0)
    _set_sample(2, "audio/x0x/808/808-SD.wav", -15.0)
    _set_sample(3, "audio/x0x/808/808-CH.wav", -10.0)
    _set_sample(4, "audio/x0x/808/808-OH.wav", -17.0)
    _set_sample(5, "audio/x0x/808/808-MA.wav", -10.0)
    _set_sample(6, "audio/x0x/808/808-RS.wav", -16.0)
    _set_sample(7, "audio/x0x/808/808-HC.wav", -20.0)

    arcify:map_encoder_via_params(1, "clock_tempo")
    arcify:map_encoder_via_params(2, "swing_amount")
    arcify:map_encoder_via_params(3, "grids_pattern_x")
    arcify:map_encoder_via_params(4, "grids_pattern_y")
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
    device = arc_device,
    delta_callback = function(n, delta)
      -- Ignore attempts to change the tempo when the tempo source is external
      if arcify:param_id_at_encoder(n) == "clock_tempo" and params:get("clock_source") ~= 1 then
        return
      end
      arcify:update(n, delta)
    end,
    refresh_callback = function(my_arc)
      arcify:redraw()
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
  _check_launch_version()
  _run_migrations()

  sequencer = Sequencer:new()
  pages_table = {
    DetailsUI:new(),
    PatternAndDensityUI:new(),
    MoreDensityUI:new(),
    EuclideanUI:new(sequencer),
  }

  init_params()
  init_ui()
  MidiOut:start_at_beginning()
  CrowIO:initialize()

  params:read()
  -- Set up the default arcify
  if _version_gt("1.6.-1", launch_version) then
    _upgrade_to_1_6_0()
  end
  params:set("cyrene_version", current_version)
  params:bang()

  _set_encoder_sensitivities()

  sequencer:initialize()
  sequencer:start()
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
    sequencer:start(true)
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

function _set_encoder_sensitivities()
  -- 1 sensitivity should be a bit slower
  norns.enc.sens(1, 5)
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
  if type(a) ~= "string" then return false end
  if type(b) ~= "string" then return true end
  local a_table = {a:match("([^.]+).([^.]+).([^.]+)")}
  local b_table = {b:match("([^.]+).([^.]+).([^.]+)")}
  if a_table == nil or #a_table ~= 3 then return false end
  if b_table == nil or #b_table ~= 3 then return true end
  for i, v in ipairs(a_table) do
    if v > b_table[i] then return true end
    if v < b_table[i] then return false end
  end
  return false
end

function _run_migrations()
  if _version_gt("1.1.-1", launch_version) then
    _upgrade_to_1_1_0()
  end
  if _version_gt("1.2.-1", launch_version) then
    _upgrade_to_1_2_0()
  end
  if _version_gt("1.7.-1", launch_version) then
    _upgrade_to_1_7_0()
  end
end

function scandir(directory)
  local i, t = 0, {}
  local pfile = io.popen('ls -a "'..directory..'"')
  if not pfile then return t end
  for filename in pfile:lines() do
    if filename ~= '.' and filename ~= '..' then
      i = i + 1
      t[i] = filename
    end
  end
  pfile:close()
  return t
end

function _rewrite_pset(transform_func)
  local dir = norns.state.data
  local files = scandir(dir)
  for i, local_filename in ipairs(files) do
    local filename = dir .. local_filename
    if filename:sub(-#".pset") == ".pset" then
      local fd = io.open(filename, "r")
      if fd then
        local contents = fd:read("*all")
        local new_contents = transform_func(contents)
        io.close(fd)
        if new_contents then
          fd = io.open(filename,"w+")
          if fd then
            io.output(fd)
            io.write(new_contents)
            io.close(fd)
          end
        end
      end
    end
  end
end

function _upgrade_to_1_1_0()
  _rewrite_pset(function(contents)
    return contents:gsub("\"8_(%S*):%s(%S*)", "")
  end)
end

function _upgrade_to_1_2_0()
  _rewrite_pset(function(contents)
    local old_pattern_length = contents:match("\"pattern_length\": (%d+)")
    if not old_pattern_length then
      return nil
    end
    local new_pattern_length = 16
    if old_pattern_length == "1" then new_pattern_length = 8
    elseif old_pattern_length == "2" then new_pattern_length = 16
    elseif old_pattern_length == "3" then new_pattern_length = 32 end
    return contents:gsub(
      "\"pattern_length\": "..old_pattern_length,
      "\"pattern_length\": "..new_pattern_length
    )
  end)
end

function _upgrade_to_1_6_0()
  arcify:map_encoder_via_params(1, "swing_amount")
  arcify:map_encoder_via_params(2, "grids_pattern_x")
  arcify:map_encoder_via_params(3, "grids_pattern_y")
  arcify:map_encoder_via_params(4, "pattern_chaos")
end

function _upgrade_to_1_7_0()
  _rewrite_pset(function(contents)
    return contents:gsub("audio/common/", "audio/x0x/")
  end)
end
