local CrowIO = {}
local c = crow

local GATE_TIME = 0.1;
local GATE_LEVEL = 5.0;

local NUM_INS = 2
local NUM_OUTS = 4
local NUM_TRACKS = 7

function CrowIO:initialize()
  _init_outputs()
  _init_inputs()
end

function CrowIO:add_params()
  params:add_group("Crow", 8)
  params:add_option("crow_out", "Enable Crow Out?", {"Off", "On"}, 2)
  params:add_option("crow_in", "Enable Crow In?", {"Off", "On"}, 2)
  for track=1, NUM_OUTS do
    params:add_number("crow_out_"..track.."_track", "out "..track..": track", 1, NUM_TRACKS, track)
  end
  for track=1, NUM_INS do
    params:add_option(
      "crow_in_"..track.."_param",
      "in "..track..": param",
      {"Off", "Tempo", "Swing", "Pattern X", "Pattern Y", "Pattern X + Y", "Chaos"},
      1
    )
  end
end

function _init_outputs()
  for track=1,NUM_OUTS do
    c.output[track].action = "pulse("..GATE_TIME..","..GATE_LEVEL..")"
  end
end

function _get_input_param(v)
  local input_params = {
    [1] = {},
    [2] = {"clock_tempo"},
    [3] = {"swing_amount"},
    [4] = {"grids_pattern_x"},
    [5] = {"grids_pattern_y"},
    [6] = {"grids_pattern_x", "grids_pattern_y"},
    [7] = {"pattern_chaos"},
  }
  return input_params[v]
end

function _init_inputs()
  for track=1,NUM_INS do
    c.input[track].mode("stream", 0.1)
    _query_input(track)
  end
end

function _query_input(track)
  local prev_val = 0

  c.input[track].stream = function(v)
    if CrowIO:is_crow_in_enabled() then
      local input_params = _get_input_param(params:get("crow_in_"..track.."_param"))
      local delta = v > prev_val and 2 or -2
      for param=1, #input_params do
        params:delta(input_params[param], delta)
      end
      prev_val = v
    end
  end
end

function CrowIO:gate_on(track)
  c.output[track].execute()
end

function CrowIO:num_outs()
  return NUM_OUTS
end

function CrowIO:is_crow_out_enabled()
  return params:get("crow_out") == 2
end

function CrowIO:is_crow_in_enabled()
  return params:get("crow_in") == 2
end

return CrowIO
