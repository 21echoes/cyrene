local CrowIO = {}
local c = crow

local ENV_ATTACK = 0.03;
local ENV_RELEASE = 0.3;
local ENV_LEVEL = 5.0;

local NUM_INS = 2
local NUM_OUTS = 4

local INPUT_PARAMS = {
  [1]={
    id="cy_grids_pattern_x",
    name="Pattern X",
    range=256
  },
  [2]={
    id="cy_grids_pattern_y",
    name="Pattern Y",
    range=256
  },
  [3]={
    id="cy_swing_amount",
    name="Swing",
    range=100
  },
  [4]={
    id="cy_pattern_chaos",
    name="Chaos",
    range=100
  }
}

function CrowIO:query_input(track)
  c.input[track].stream = function(v)
    if CrowIO:is_crow_in_enabled() then
      local input_param = INPUT_PARAMS[params:get("cy_crow_in_"..track.."_param")]

      if input_param then
        local next_val = math.ceil(input_param["range"] * ((v + 5) / 10))
        params:set(input_param["id"], next_val)
      end
    end
  end
end

function CrowIO:init_inputs()
  for track=1,NUM_INS do
    c.input[track].mode("stream", 0.1)
    self:query_input(track)
  end
end

function CrowIO:initialize()
  self:init_inputs()
end

function CrowIO:add_params(num_tracks, arcify, is_mod)
  params:add_group("Crow", 20)
  params:add_option("cy_crow_out", "Enable Crow Out?", {"Off", "On"}, is_mod and 1 or 2)
  params:add_option("cy_crow_in", "Enable Crow In?", {"Off", "On"}, is_mod and 1 or 2)
  for track=1, NUM_OUTS do
    local track_param_id = "cy_crow_out_"..track.."_track"
    params:add_number(track_param_id, "out "..track..": track", 1, num_tracks, track)
    if arcify then arcify:register(track_param_id) end
    local mode_param_id = "cy_crow_out_"..track.."_mode"
    params:add_option(mode_param_id, "out "..track..": mode", {"Off", "Env", "Gate"}, 3)
    if arcify then arcify:register(mode_param_id) end
    local attack_param_id = "cy_crow_out_"..track.."_attack"
    params:add_control(attack_param_id, "out "..track..": attack", controlspec.new(0.03, 10, 'lin', 0, ENV_ATTACK))
    if arcify then arcify:register(attack_param_id) end
    local release_param_id = "cy_crow_out_"..track.."_release"
    params:add_control(release_param_id, "out "..track..": release", controlspec.new(0.03, 10, 'lin', 0, ENV_RELEASE))
    if arcify then arcify:register(release_param_id) end
  end
  for track=1, NUM_INS do
    local param_id = "cy_crow_in_"..track.."_param"
    params:add_option(
      param_id,
      "in "..track..": param",
      {"Pattern X", "Pattern Y", "Swing", "Chaos", "Off"},
      1
    )
    if arcify then arcify:register(param_id) end
  end
end

function CrowIO:gate_on(track)
  local type = params:get("cy_crow_out_"..track.."_mode")

  if type == 1 then
    return
  elseif type == 2 then
    local attack = params:get("cy_crow_out_"..track.."_attack")
    local release = params:get("cy_crow_out_"..track.."_release")
    c.output[track].action = "ar("..attack..", "..release..", "..ENV_LEVEL..")"
  elseif type == 3 then
    c.output[track].action = "pulse(0.25, 5, 1)"
  end
  c.output[track]()
end

function CrowIO:num_outs()
  return NUM_OUTS
end

function CrowIO:is_crow_out_enabled()
  return params:get("cy_crow_out") == 2
end

function CrowIO:is_crow_in_enabled()
  return params:get("cy_crow_in") == 2
end

return CrowIO
