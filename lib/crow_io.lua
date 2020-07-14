local CrowIO = {}
local c = crow

local ENV_ATTACK = 0.03;
local ENV_RELEASE = 0.3;
local ENV_LEVEL = 5.0;

local NUM_INS = 2
local NUM_OUTS = 4
local NUM_TRACKS = 7

local INPUT_PARAMS = {
  [1]={
    id="grids_pattern_x",
    name="Pattern X",
    range=256
  },
  [2]={
    id="grids_pattern_y",
    name="Pattern Y",
    range=256
  },
  [3]={
    id="swing_amount",
    name="Swing",
    range=100
  },
  [4]={
    id="pattern_chaos",
    name="Chaos",
    range=100
  }
}

local function init_outputs()
  for track=1,NUM_OUTS do
    local attack = params:get("crow_out_"..track.."_attack")
    local release = params:get("crow_out_"..track.."_release")
    c.output[track].action = "ar("..attack..", "..release..", "..ENV_LEVEL..")"
  end
end

local function query_input(track)
  c.input[track].stream = function(v)
    if CrowIO:is_crow_in_enabled() then
      local input_param = INPUT_PARAMS[params:get("crow_in_"..track.."_param")]

      if input_param then
        local next_val = math.ceil(input_param["range"] * ((v + 5) / 10))
        params:set(input_param["id"], next_val)
      end
    end
  end
end

local function init_inputs()
  for track=1,NUM_INS do
    c.input[track].mode("stream", 0.1)
    query_input(track)
  end
end

function CrowIO:initialize()
  init_outputs()
  init_inputs()
end

function CrowIO:add_params()
  params:add_group("Crow", 16)
  params:add_option("crow_out", "Enable Crow Out?", {"Off", "On"}, 2)
  params:add_option("crow_in", "Enable Crow In?", {"Off", "On"}, 2)
  for track=1, NUM_OUTS do
    params:add_number("crow_out_"..track.."_track", "out "..track..": track", 1, NUM_TRACKS, track)
    params:add_control("crow_out_"..track.."_attack", "out "..track..": attack", controlspec.new(0.03, 10, 'lin', 0, ENV_ATTACK))
    params:add_control("crow_out_"..track.."_release", "out "..track..": release", controlspec.new(0.03, 10, 'lin', 0, ENV_RELEASE))
  end
  for track=1, NUM_INS do
    params:add_option(
      "crow_in_"..track.."_param",
      "in "..track..": param",
      {"Pattern X", "Pattern Y", "Swing", "Chaos", "Off"},
      1
    )
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