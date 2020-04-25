--- PatternUI
-- @classmod PatternUI

local UI = require "ui"
local Label = include("lib/ui/util/label")

local PatternUI = {}

function PatternUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  -- i.tab_bypass_label = Label.new({y = 56})
  i.x_dial = UI.Dial.new(16, 12, 22, 128, 0, 255, 1)
  i.y_dial = UI.Dial.new(53, 12, 22, 128, 0, 255, 1)
  i.chaos_dial = UI.Dial.new(90, 12, 22, 128, 0, 255, 1)

  return i
end

function PatternUI:add_params()
end

function PatternUI:redraw(sequencer)
  self.x_dial:redraw()
  self.y_dial:redraw()
  self.chaos_dial:redraw()
end

return PatternUI
