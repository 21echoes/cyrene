local CrowIO = {}
local c = crow

local GATE_TIME = 0.1;
local GATE_LEVEL = 5.0;

local NUM_OUTS = 4

function CrowIO:init()
  for track=1,NUM_OUTS do
    c.output[track].action = "pulse("..GATE_TIME..","..GATE_LEVEL..")"
  end
end

function CrowIO:note_on(track)
  c.output[track].execute()
end

function CrowIO:num_outs()
  return NUM_OUTS
end

return CrowIO