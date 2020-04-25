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
local UI = require 'ui'
local Sequencer = include('lib/sequencer')
local DetailsUI = include('lib/ui/details')
local PatternUI = include('lib/ui/pattern')
local DensityUI = include('lib/ui/density')
local UIState = include('lib/ui/util/devices')

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
  sequencer:add_params()
  for i, page in ipairs(pages_table) do
    pages_table[i]:add_params()
  end
  params:add_separator()
  Ack.add_params()
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
          set_trig(
          sequencer:set_trig(
            params:get("pattern"),
            x,
            y,
            not sequencer:trig_is_set(params:get("pattern"), x, y)
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

  UIState.init_screen {
    refresh_callback = function()
      redraw()
    end
  }

  init_60_fps_ui_refresh_metro()
end

function init()
  sequencer = Sequencer:new()
  pages_table = {
    DetailsUI:new(),
    -- TODO: there's probably no need to have these be two separate pages. just one page, six knobs?
    PatternUI:new(),
    DensityUI:new(),
  }

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
