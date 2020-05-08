local er = require "er"

local Euclidean = {}

function Euclidean.get_pattern(trigs, length, rotation)
  if trigs == 0 then
    local result = {}
    for i=1,length do
      table.insert(result, false)
    end
    return result
  end
  return Euclidean.rotate_pattern(er.gen(trigs, length), rotation)
end

function Euclidean.rotate_pattern(pattern, rotation)
  -- rotate_pattern comes to us via justmat, okyeron, and stackexchange
  local pattern_length = #pattern
  rotation = rotation % pattern_length
  if rotation == 0 then return pattern end
  local result = {}
  for i = 1, rotation do
    result[i] = pattern[pattern_length - rotation + i]
  end
  for i = rotation + 1, pattern_length do
    result[i] = pattern[i - rotation]
  end
  return result
end

return Euclidean
