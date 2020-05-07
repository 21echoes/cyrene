local UIState = include('lib/ui/util/devices')

-- Make sure there's only one copy
if _Grid ~= nil then return _Grid end

local MAX_GRID_WIDTH = 16
local HEIGHT = 8
local CLICK_DURATION = 0.7

local TRIG_LEVEL = 15
local MIN_TRIG_LEVEL = 3
local PLAYPOS_LEVEL = 7
local ACTIVE_ALT_LEVEL = 15
local INACTIVE_ALT_LEVEL = 3
local ACTIVE_PAGE_LEVEL = 15
local INACTIVE_PAGE_LEVEL = 3
local CLEAR_LEVEL = 0

local Grid = {
  connected_grid = nil,
  grid_width = MAX_GRID_WIDTH,
  page_number = 1,
  grid_alt_key_down_time = nil,
  grid_alt_action_taken = false,
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
          -- Handle jumpcuts by telling the sequencer where to cut to
          local trig_x = Grid._sequencer_pos(x)
          sequencer.queued_playpos = trig_x-1
          UIState.screen_dirty = true
        end
      elseif state == 1 then
        if Grid.grid_alt_key_down_time then
          -- TODO: probability page for the selected track
        else
          -- Clicks in other rows while not holding the alt key toggle the trigger in that slot
          local trig_x = Grid._sequencer_pos(x)
          sequencer:set_trig(
            params:get("pattern"),
            trig_x,
            y,
            sequencer:trig_level(params:get("pattern"), trig_x, y) == 0 and 255 or 0
          )
        end
      end
      UIState.grid_dirty = true
      UIState.flash_event()
    end,
    refresh_callback = function(my_grid)
      Grid.connected_grid = my_grid
      local function refresh_grid_button(x, y)
        if y == 8 then
          if x == Grid.grid_width then
            -- Bottom right is the alt key. Always show it slightly glowing (or full glow when held)
            if Grid.grid_alt_key_down_time then
              my_grid:led(x, y, ACTIVE_ALT_LEVEL)
            else
              my_grid:led(x, y, INACTIVE_ALT_LEVEL)
            end
          elseif Grid.grid_alt_key_down_time then
            -- If the alt key is being held, use the bottom left corner to show pagination options
            if x == Grid.page_number then
              my_grid:led(x, y, ACTIVE_PAGE_LEVEL)
            elseif x <= Grid._last_page_number(sequencer) then
              my_grid:led(x, y, INACTIVE_PAGE_LEVEL)
            else
              my_grid:led(x, y, CLEAR_LEVEL)
            end
          else
            -- Otherwise the last row is just normal blank tiles (which can track the play position)
            local trig_x = Grid._sequencer_pos(x)
            if trig_x-1 == sequencer.playpos then
              my_grid:led(x, y, PLAYPOS_LEVEL)
            else
              my_grid:led(x, y, CLEAR_LEVEL)
            end
          end
        else
          -- All rows that aren't the bottom row show triggers if active, or the play position otherwise
          local trig_x = Grid._sequencer_pos(x)
          local trig_level = sequencer:trig_level(params:get("pattern"), trig_x, y)
          if trig_level == 0 then
            if trig_x-1 == sequencer.playpos then
              my_grid:led(x, y, PLAYPOS_LEVEL)
            else
              my_grid:led(x, y, CLEAR_LEVEL)
            end
          else
            -- Show the likelihood of a trigger firing via its brightness (down to some minimum brightness)
            local grid_trig_level = math.ceil((trig_level / 255) * (TRIG_LEVEL - MIN_TRIG_LEVEL)) + MIN_TRIG_LEVEL
            my_grid:led(x, y, grid_trig_level)
          end
        end
      end

      local function refresh_grid()
        for x=1,Grid.grid_width do
          for y=1,HEIGHT do
            refresh_grid_button(x, y)
          end
        end
      end

      refresh_grid()
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

-- Make sure there's only one copy
if _Grid == nil then
  _Grid = Grid
end
return _Grid
