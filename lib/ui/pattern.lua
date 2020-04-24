--- PatternUI
-- @classmod PatternUI

local UI = require "ui"
local Label = include("lib/ui/util/label")

local PatternUI = {}

function PatternUI:new(bypass_by_default)
  i = {}
  setmetatable(i, self)
  self.__index = self

  -- i.tab_bypass_label = Label.new({y = 56})
  i.x_dial = UI.Dial.new(16, 12, 22, 50, 0, 100, 1)
  i.y_dial = UI.Dial.new(53, 12, 22, 50, 0, 100, 1)
  i.chaos_dial = UI.Dial.new(90, 12, 22, 50, 0, 100, 1)

  return i
end

return PatternUI
