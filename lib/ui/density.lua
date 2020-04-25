--- DensityUI
-- @classmod DensityUI

local UI = require "ui"
local Label = include("lib/ui/util/label")

local DensityUI = {}

function DensityUI:new()
  i = {}
  setmetatable(i, self)
  self.__index = self

  -- i.tab_bypass_label = Label.new({y = 56})
  i.kick_density_dial = UI.Dial.new(16, 34, 22, 50, 0, 100, 1)
  i.snare_density_dial = UI.Dial.new(53, 34, 22, 50, 0, 100, 1)
  i.hat_density_dial = UI.Dial.new(90, 34, 22, 50, 0, 100, 1)

  return i
end

return DensityUI
