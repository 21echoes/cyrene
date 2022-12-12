local UIState = require('cyrene/lib/ui/util/devices')

-- Make sure there's only one copy
if _Grid ~= nil then return _Grid end

local MAX_GRID_WIDTH = 16
local HEIGHT = 8
local CLICK_DURATION = 0.7

local TRIG_LEVEL = 15
local MIN_TRIG_LEVEL = 2
local PLAYPOS_LEVEL = 7
local ACTIVE_ALT_LEVEL = 15
local INACTIVE_ALT_LEVEL = 4
local ACTIVE_PAGE_LEVEL = 15
local INACTIVE_PAGE_LEVEL = 4
local CLEAR_LEVEL = 0

local Trigs = {}
local Probabilities = {track=1}

local Grid = {
  connected_grid = nil,
  grid_width = MAX_GRID_WIDTH,
  page_number = 1,
  grid_alt_key_down_time = nil,
  grid_alt_action_taken = false,
  mode = Trigs,
}

function Grid.init(sequencer)
  UIState.init_grid {
    device = grid.connect(),
    key_callback = function(x, y, state)
      if y == 8 then
        local last_row_click = false
        -- The bottom right key is an "alt" key
        if x == Grid.grid_width then
          if state == 1 then
            Grid.grid_alt_key_down_time = util.time()
          else
            if Grid.grid_alt_key_down_time then
              local key_down_duration = util.time() - Grid.grid_alt_key_down_time
              Grid.grid_alt_key_down_time = nil
              -- only count this as a click if no alt action was taken, and if the hold was short enough
              if not (Grid.grid_alt_action_taken or key_down_duration > CLICK_DURATION) then
                last_row_click = true
              end
              Grid.grid_alt_action_taken = false
            end
          end
        elseif state == 1 then
          -- Otherwise we only care about key downs
          -- Key downs in the last row while holding alt are attempts at pagination
          if Grid.grid_alt_key_down_time then
            -- Only paginate if they clicked a valid page
            if x <= Grid._last_page_number(sequencer) then
              Grid.page_number = x
              Grid.grid_alt_action_taken = true
            end
          else
            -- If we weren't in alt mode, this is your standard jumpcut
            last_row_click = true
          end
        end
        if last_row_click then
          Grid.mode.key_callback(x, y, 1, sequencer)
          UIState.screen_dirty = true
        end
      else
        Grid.mode.key_callback(x, y, state, sequencer)
      end
      UIState.grid_dirty = true
      UIState.flash_event()
    end,
    refresh_callback = function(my_grid)
      Grid.connected_grid = my_grid
      for x=1,Grid.grid_width do
        for y=1,HEIGHT do
          if y == 8 then
            if x == Grid.grid_width then
              -- Bottom right is the alt key. Always show it slightly glowing (or full glow when held)
              if Grid.grid_alt_key_down_time then
                Grid.connected_grid:led(x, y, ACTIVE_ALT_LEVEL)
              else
                Grid.connected_grid:led(x, y, INACTIVE_ALT_LEVEL)
              end
            elseif Grid.grid_alt_key_down_time then
              -- If the alt key is being held, use the bottom left corner to show pagination options
              if x == Grid.page_number then
                Grid.connected_grid:led(x, y, ACTIVE_PAGE_LEVEL)
              elseif x <= Grid._last_page_number(sequencer) then
                Grid.connected_grid:led(x, y, INACTIVE_PAGE_LEVEL)
              else
                Grid.connected_grid:led(x, y, CLEAR_LEVEL)
              end
            else
              -- Otherwise the last row is just normal tiles
              Grid.mode.refresh_grid_button(x, y, sequencer)
            end
          else
            Grid.mode.refresh_grid_button(x, y, sequencer)
          end
        end
      end
    end,
    width_changed_callback = function(new_width)
      Grid.grid_width = new_width
      UIState.grid_dirty = true
    end
  }
end

function Grid.cleanup()
  if Grid.connected_grid and Grid.connected_grid.device then
    Grid.connected_grid:all(0)
    Grid.connected_grid:refresh()
  end
end

function Grid._sequencer_pos(grid_x)
  return grid_x + (Grid.grid_width * (Grid.page_number - 1))
end

function Grid._last_page_number(sequencer)
  return math.ceil(sequencer:get_pattern_length() / Grid.grid_width)
end

------------------
-- Trigger mode --
------------------

function Trigs.key_callback(x, y, state, sequencer)
  -- Only count key downs
  if state ~= 1 then return end
  if y == 8 then
    if not Grid.grid_alt_key_down_time then
      -- If we weren't in alt mode, this is your standard jumpcut
      -- Handle jumpcuts by telling the sequencer where to cut to
      local trig_x = Grid._sequencer_pos(x)
      sequencer.queued_playpos = trig_x-1
    end
  else
    if Grid.grid_alt_key_down_time then
      -- Switch to probability mode for the clicked track
      Probabilities.track = y
      Grid.mode = Probabilities
    else
      -- Clicks in rows 1-7 while not holding the alt key toggle the trigger in that slot
      local trig_x = Grid._sequencer_pos(x)
      sequencer:set_trig(
        params:get("cy_pattern"),
        trig_x,
        y,
        sequencer:trig_level(params:get("cy_pattern"), trig_x, y) == 0 and 255 or 0
      )
    end
  end
end

function Trigs.refresh_grid_button(x, y, sequencer)
  -- All rows that aren't the bottom row show triggers if active, or the play position otherwise
  local trig_x = Grid._sequencer_pos(x)
  local trig_level = y ~= 8 and sequencer:trig_level(params:get("cy_pattern"), trig_x, y) or 0
  if trig_level == 0 then
    -- If there's no trigger in the slot, show the playhead if it's in our column, otherwise show empty
    if trig_x-1 == sequencer.playpos then
      Grid.connected_grid:led(x, y, PLAYPOS_LEVEL)
    else
      Grid.connected_grid:led(x, y, CLEAR_LEVEL)
    end
  else
    -- Show the likelihood of a trigger firing via its brightness (down to some minimum brightness)
    local grid_trig_level = math.ceil(util.linexp(0, 255, MIN_TRIG_LEVEL, TRIG_LEVEL, trig_level))
    -- Fade out the columns beyond the end of the pattern
    local is_beyond_pattern_end = trig_x > sequencer:get_pattern_length()
    grid_trig_level = is_beyond_pattern_end and math.ceil(grid_trig_level * 0.33) or grid_trig_level
    Grid.connected_grid:led(x, y, grid_trig_level)
  end
end

------------------------
-- Probabilities mode --
------------------------

function Probabilities.key_callback(x, y, state, sequencer)
  -- Only count key downs
  if state ~= 1 then return end
  if y == 8 then
    if x == Grid.grid_width - 1 and not Grid.grid_alt_key_down_time then
      -- Key next to alt key takes back to Trigs mode
      Grid.mode = Trigs
    end
  elseif not Grid.grid_alt_key_down_time then
    -- Clicks in rows 1-7 set the trig level based on the row clicked
    local trig_x = Grid._sequencer_pos(x)
    local trig_level = math.floor(255 * (7 - y) / 6)
    sequencer:set_trig(params:get("cy_pattern"), trig_x, Probabilities.track, trig_level)
  end
end

function Probabilities.refresh_grid_button(x, y, sequencer)
  -- Show a page back button next to the alt button
  if y == 8 and x == Grid.grid_width - 1 then
    Grid.connected_grid:led(x, y, INACTIVE_ALT_LEVEL)
    return
  end
  -- All rows that aren't the bottom row show the trig_level in the appropriate row, or the play position otherwise
  local show_playhead = true
  local trig_x = Grid._sequencer_pos(x)
  if y ~= 8 then
    local trig_level = sequencer:trig_level(params:get("cy_pattern"), trig_x, Probabilities.track)
    local row_for_level = math.floor(-1 * (((trig_level/255) * 6) - 7))
    show_playhead = y ~= row_for_level
  end
  if show_playhead then
    -- If there's no trigger in the slot, show the playhead if it's in our column, otherwise show empty
    if trig_x-1 == sequencer.playpos then
      Grid.connected_grid:led(x, y, PLAYPOS_LEVEL)
    else
      Grid.connected_grid:led(x, y, CLEAR_LEVEL)
    end
  else
    local is_beyond_pattern_end = trig_x > sequencer:get_pattern_length()
    grid_trig_level = is_beyond_pattern_end and math.ceil(TRIG_LEVEL * 0.33) or TRIG_LEVEL
    Grid.connected_grid:led(x, y, grid_trig_level)
  end
end

-- Make sure there's only one copy
if _Grid == nil then
  _Grid = Grid
end
return _Grid
