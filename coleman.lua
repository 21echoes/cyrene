-- Coleman, a drummer in a box
--
-- Pattern page:
-- E2 & E3 control pattern
-- E1 adds randomness
--
-- Density page:
-- E1, E2, & E3 control
-- hat, kick, snare
--
-- Adapted from Grids
--   by Emilie Gillet
-- and Step, by @jah
--
-- v0.0.1 @21echoes

engine.name = 'Ack'

local Ack = require 'ack/lib/ack'
local Sequencer = include('lib/sequencer')
local UI = include('lib/ui/util/devices')

local TRIG_LEVEL = 15
local PLAYPOS_LEVEL = 7
local CLEAR_LEVEL = 0

-- TODO: these are duplicated in sequencer.lua
local MAX_GRID_WIDTH = 16
local HEIGHT = 8

local sequencer

local function init_params()
  params:add {
    type="option",
    id="last_row_cuts",
    name="Last Row Cuts",
    options={"No", "Yes"},
    default=1
  }

  params:add {
    type="option",
    id="cut_quant",
    name="Quantize Cutting",
    options={"No", "Yes"},
    default=1
  }

  sequencer:add_params()

  params:add_separator()

  Ack.add_params()
end

local function cutting_is_enabled()
  return params:get("last_row_cuts") == 2
end

local function init_60_fps_ui_refresh_metro()
  local ui_refresh_metro = metro.init()
  ui_refresh_metro.event = UI.refresh
  ui_refresh_metro.time = 1/60
  ui_refresh_metro:start()
end

local function init_ui()
  UI.init_arc {
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

  UI.init_grid {
    device = grid.connect(),
    key_callback = function(x, y, state)
      if state == 1 then
        if cutting_is_enabled() and y == 8 then
          sequencer.queued_playpos = x-1
          UI.screen_dirty = true
        else
          set_trig(
          sequencer:set_trig(
            params:get("pattern"),
            x,
            y,
            not sequencer:trig_is_set(params:get("pattern"), x, y)
          )
          UI.grid_dirty = true
        end
      end
      UI.flash_event()
    end,
    refresh_callback = function(my_grid)
      local function refresh_grid_button(x, y)
        if cutting_is_enabled() and y == 8 then
          if x-1 == sequencer.playpos then
            my_grid:led(x, y, PLAYPOS_LEVEL)
          else
            my_grid:led(x, y, CLEAR_LEVEL)
          end
        else
          if sequencer:trig_is_set(params:get("pattern"), x, y) then
            my_grid:led(x, y, TRIG_LEVEL)
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

  UI.init_screen {
    refresh_callback = function()
      redraw()
    end
  }

  init_60_fps_ui_refresh_metro()
end

function init()
  sequencer = Sequencer:new()

  init_params()
  init_ui()

  sequencer:initialize()
  sequencer:start()

  params:read()
  params:bang()
end

function cleanup()
  params:write()

  sequencer:save_patterns()

  if my_grid.device then
    my_grid:all(0)
    my_grid:refresh()
  end
end

function redraw()
  local hi_level = 15
  local lo_level = 4

  local enc1_x = 0
  local enc1_y = 12

  local enc2_x = 16
  local enc2_y = 32

  local enc3_x = enc2_x+45
  local enc3_y = enc2_y

  local key2_x = 0
  local key2_y = 63

  local key3_x = key2_x+45
  local key3_y = key2_y

  local function redraw_enc1_widget()
    screen.move(enc1_x, enc1_y)
    screen.level(lo_level)
    screen.text("LEVEL")
    screen.move(enc1_x+45, enc1_y)
    screen.level(hi_level)
    screen.text(util.round(mix:get_raw("output")*100, 1))
  end

  local function redraw_event_flash_widget()
    screen.level(lo_level)
    screen.rect(122, enc1_y-7, 5, 5)
    screen.fill()
  end

  local function redraw_enc2_widget()
    screen.move(enc2_x, enc2_y)
    screen.level(lo_level)
    screen.text("BPM")
    screen.move(enc2_x, enc2_y+12)
    screen.level(hi_level)
    screen.text(util.round(params:get("tempo"), 1))
  end

  local function redraw_enc3_widget()
    screen.move(enc3_x, enc3_y)
    screen.level(lo_level)
    screen.text("SWING")
    screen.move(enc3_x, enc3_y+12)
    screen.level(hi_level)
    screen.text(util.round(params:get("swing_amount"), 1))
    screen.text("%")
  end

  local function redraw_key2_widget()
    screen.move(key2_x, key2_y)
    if sequencer.playing then
      screen.level(lo_level)
    else
      screen.level(hi_level)
    end
    screen.text("STOP")
  end

  local function redraw_key3_widget()
    screen.move(key3_x, key3_y)
    if sequencer.playing then
      screen.level(hi_level)
    else
      screen.level(lo_level)
    end
    screen.text("PLAY")

    if sequencer.playing then
      screen.move(key3_x+44, key3_y)
      screen.level(hi_level)
      screen.text(sequencer.playpos+1)
    end
  end

  screen.font_size(16)
  screen.clear()

  redraw_enc1_widget()

  if UI.show_event_indicator then
    redraw_event_flash_widget()
  end

  redraw_enc2_widget()
  redraw_enc3_widget()
  redraw_key2_widget()
  redraw_key3_widget()

  screen.update()
end

function enc(n, delta)
  if n == 1 then
    mix:delta("output", delta)
    UI.screen_dirty = true
  elseif n == 2 then
    params:delta("tempo", delta)
  elseif n == 3 then
    params:delta("swing_amount", delta)
  end
end

function key(n, s)
  if n == 2 and s == 1 then
    if sequencer.playing == false then
      sequencer:move_to_start()
      UI.grid_dirty = true
    else
      sequencer:stop()
    end
  elseif n == 3 and s == 1 then
    sequencer:start()
  end
  UI.screen_dirty = true
end
