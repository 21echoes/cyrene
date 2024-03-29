local ControlSpec = require 'controlspec'
local UI = require('cyrene/lib/ui/util/devices')
local DrumMap = require('cyrene/lib/grids_patterns')
local Euclidean = require('cyrene/lib/euclidean')
local MidiOut = require('cyrene/lib/midi_out')
local EuclideanUI = require('cyrene/lib/ui/euclidean')
local CrowIO = require('cyrene/lib/crow_io')

local PATTERN_FILE = "step.data"

local NUM_PATTERNS = 50
local ppqn = 24

local MAX_PATTERN_LENGTH = 32
local HEIGHT = 8
local NUM_TRACKS = HEIGHT - 1

local tempo_spec = ControlSpec.new(20, 300, ControlSpec.WARP_LIN, 0, 120, "BPM")
local swing_amount_spec = ControlSpec.new(0, 100, ControlSpec.WARP_LIN, 0, 0, "%")

local MIN_ENGINE_VOL = -40

local Sequencer = {}

function Sequencer:new(action, num_tracks, is_mod)
  i = {}
  setmetatable(i, self)
  self.__index = self

  i._is_initialized = false
  i._is_mod = is_mod or false
  i.trigs = {}
  i:_init_trigs()
  i.playing = false
  i.playpos = -1
  i._action = action
  i.num_tracks = num_tracks or NUM_TRACKS
  i.ticks_to_next = nil
  i._raw_ticks = nil
  i.queued_playpos = nil
  i.grids_x = nil
  i.grids_y = nil
  i._euclidean_kick = nil
  i._euclidean_snare = nil
  i._euclidean_hat = nil
  i._part_perturbations = {}
  for track=1,NUM_TRACKS do
    i._part_perturbations[track] = 0
  end
  i._clock_id = nil
  i._shuffle_basis_index = 0
  i._shuffle_feel_index = 1
  i._ppqn_error = 0
  i._engine_enabled = not is_mod

  return i
end

function Sequencer:add_params(arcify)
  params:add_separator("Cyrene")
  params:add {
    id="cyrene_version",
    name="Cyrene Version",
    type="text",
  }
  params:hide(params.lookup["cyrene_version"])

  if arcify then
    arcify:register("clock_tempo")
    arcify:register("clock_source")
  end

  params:add {
    type="binary",
    id="cy_play",
    name="Play",
    default=0,
    behavior="toggle",
    action=function(a)
      if a > 0 then
        self:_start()
      else
        self:_stop()
      end
    end,
  }
  params:add {
    type="trigger",
    id="cy_reset",
    name="Reset",
    action=function(a)
      self:_move_to_start()
    end,
  }

  if not self._is_mod then
    params:add {
      type="number",
      id="cy_pattern",
      name="Pattern",
      min=1,
      max=NUM_PATTERNS,
      default=1,
      action=function()
        UI.grid_dirty = true
      end
    }
    if arcify then arcify:register("cy_pattern") end
  end
  params:add {
    type="number",
    id="cy_pattern_length",
    name="Pattern Length",
    min=1,
    max=MAX_PATTERN_LENGTH,
    default=16
  }
  if arcify then arcify:register("cy_pattern_length") end
  params:add {
    type="option",
    id="cy_grid_resolution",
    name="Grid Resolution",
    options={"Quarters", "8ths", "16ths", "32nds"},
    default=3,
    action=function(val)
      if self.grids_x ~= nil and self.grids_y ~= nil then
        local patternno = self:_get_pattern_number()
        self:set_grids_xy(patternno, params:get("cy_grids_pattern_x"), params:get("cy_grids_pattern_y"), true)
      end
      self:_update_clock_sync_resolution()
    end
  }
  if arcify then arcify:register("cy_grid_resolution") end
  params:add {
    type="option",
    id="cy_shuffle_basis",
    name="Shuffle Basis",
    options={
      "Simple",
      "9-tuplets",
      "7-tuplets",
      "5-tuplets",
      "6-tuplets",
      "Weird 8s",
      "Weird 9s"
    },
    default=1,
    action=function(val)
      self:update_swing()
      UI.params_dirty = true
      UI.screen_dirty = true
      UI.arc_dirty = true
    end
  }
  if arcify then arcify:register("cy_shuffle_basis") end
  params:add {
    type="option",
    id="cy_shuffle_feel",
    name="Shuffle Feel",
    options={
      "Drunk",
      "Smooth",
      "Heavy",
      "Clave",
    },
    default=1,
    action=function(val)
      UI.params_dirty = true
      UI.screen_dirty = true
      UI.arc_dirty = true
    end
  }
  if arcify then arcify:register("cy_shuffle_feel") end
  params:add {
    type="control",
    id="cy_swing_amount",
    name="Swing Amount",
    controlspec=swing_amount_spec,
    action=function(val)
      self:update_swing()
      UI.params_dirty = true
      UI.screen_dirty = true
      UI.arc_dirty = true
    end
  }
  if arcify then arcify:register("cy_swing_amount") end
  if not self._is_mod then
    params:add {
      type="option",
      id="cy_cut_quant",
      name="Quantize Cutting",
      options={"No", "Yes"},
      default=1
    }
    if arcify then arcify:register("cy_cut_quant") end
  end

  local default_tempo_action = params:lookup_param("clock_tempo").action
  params:set_action("clock_tempo", function(val)
    default_tempo_action(val)
    UI.arc_dirty = true
    UI.screen_dirty = true
  end)
  local default_clock_source_action = params:lookup_param("clock_source").action
  params:set_action("clock_source", function(val)
    UI.screen_dirty = true
    default_clock_source_action(val)
  end)

  params:add {
    type="number",
    id="cy_grids_pattern_x",
    name="Pattern X",
    min=0,
    max=255,
    default=128,
    action=function(value) UI.screen_dirty = true end
  }
  if arcify then arcify:register("cy_grids_pattern_x") end
  params:add {
    type="number",
    id="cy_grids_pattern_y",
    name="Pattern Y",
    min=0,
    max=255,
    default=128,
    action=function(value) UI.screen_dirty = true end
  }
  if arcify then arcify:register("cy_grids_pattern_y") end
  params:add {
    type="number",
    id="cy_pattern_chaos",
    name="Chaos",
    min=0,
    max=100,
    default=10,
    formatter=function(param) return param.value .. "%" end,
    action=function(value)
      UI.params_dirty = true
      UI.screen_dirty = true
    end
  }
  if arcify then arcify:register("cy_pattern_chaos") end
end

function Sequencer:add_params_for_track(track, arcify, pages)
  local density_param_id = "cy_"..track.."_density"
  local density_param_name = track..": Density"
  params:add {
    type="number",
    id=density_param_id,
    name=density_param_name,
    min=0,
    max=100,
    default=50,
    formatter=function(param) return param.value .. "%" end,
    action=function(value)
      UI.params_dirty = true
      UI.screen_dirty = true
    end
  }
  if arcify then arcify:register(density_param_id) end

  local eucl_mode_param_id = "cy_"..track.."_euclidean_enabled"
  params:add {
    type="option",
    id=eucl_mode_param_id,
    name=track..": Euclidean Mode",
    options={"Off", "On"},
    default=1,
    action=function(value)
      self:recompute_euclidean_for_track(track)
      UI.params_dirty = true
      UI.screen_dirty = true
    end
  }
  if arcify then arcify:register(eucl_mode_param_id) end
  local eucl_length_param_id = "cy_"..track.."_euclidean_length"
  local eucl_trigs_param_id = "cy_"..track.."_euclidean_trigs"
  params:add {
    type="number",
    id=eucl_length_param_id,
    name=track..": Euclidean Length",
    min=1,
    max=MAX_PATTERN_LENGTH,
    default=8,
    action=function(value)
      if value < params:get(eucl_trigs_param_id) then
        params:set(eucl_trigs_param_id, value)
      end
      self:recompute_euclidean_for_track(track)
      UI.params_dirty = true
      UI.screen_dirty = true
    end
  }
  if arcify then arcify:register(eucl_length_param_id) end
  params:add {
    type="number",
    id=eucl_trigs_param_id,
    name=track..": Euclidean Count",
    min=0,
    max=MAX_PATTERN_LENGTH,
    default=0,
    action=function(value)
      local eucl_length = params:get(eucl_length_param_id)
      if value > eucl_length then
        params:set(eucl_trigs_param_id, eucl_length)
        value = eucl_length
      end
      self:recompute_euclidean_for_track(track)
      UI.params_dirty = true
      UI.screen_dirty = true
    end
  }
  if arcify then arcify:register(eucl_trigs_param_id) end
  local eucl_rotation_param_id = "cy_"..track.."_euclidean_rotation"
  params:add {
    type="number",
    id=eucl_rotation_param_id,
    name=track..": Euclidean Rotate",
    min=0,
    max=MAX_PATTERN_LENGTH - 1,
    default=0,
    action=function(value)
      local eucl_length = params:get(eucl_length_param_id)
      if value > eucl_length - 1 then
        params:set(eucl_rotation_param_id, eucl_length - 1)
        value = eucl_length - 1
      end
      self:recompute_euclidean_for_track(track)
      UI.params_dirty = true
      UI.screen_dirty = true
    end
  }
  if arcify then arcify:register(eucl_rotation_param_id) end
end

function Sequencer:initialize()
  self:_update_clock_sync_resolution()
  self:load_patterns()
  self._is_initialized = true
end

function Sequencer:_start(immediately)
  if not self._is_initialized then return end
  if self.playing then return end
  self.playing = true
  if self._clock_id ~= nil then
    clock.cancel(self._clock_id)
  end
  if immediately then
    -- run the non-sync() innards of _clock_tick before running _clock_tick
    self:tick()
  end
  self._clock_id = clock.run(self._clock_tick, self)
end

function Sequencer:_move_to_start()
  self.playpos = -1
  self.queued_playpos = 0
end

function Sequencer:_stop()
  if not self.playing then return end
  self.playing = false
  MidiOut:turn_off_active_notes(self.num_tracks)
  if self._clock_id ~= nil then
    clock.cancel(self._clock_id)
    self._clock_id = nil
  end
end

function Sequencer:set_trig(patternno, step, track, value)
  self.trigs[patternno][track][step] = value
end

function Sequencer:trig_level(patternno, x, y)
  return self.trigs[patternno][y][x] or 0
end

function Sequencer:_init_trigs()
  for patternno=1,NUM_PATTERNS do
    self.trigs[patternno] = {}
    for y=1,NUM_TRACKS do
      self.trigs[patternno][y] = {}
      for x=1,MAX_PATTERN_LENGTH do
        self.trigs[patternno][y][x] = 0
      end
    end
  end
end

function Sequencer:_get_pattern_number()
  if self._is_mod then
    return 1
  end
  return params:get("cy_pattern")
end

function Sequencer:get_pattern_length()
  return params:get("cy_pattern_length")
end

function Sequencer:set_pattern_length(pattern_length)
  params:set("cy_pattern_length", pattern_length)
end

function Sequencer:save_patterns()
  if self._is_mod then return end
  local fd=io.open(norns.state.data .. PATTERN_FILE,"w+")
  io.output(fd)
  for patternno=1,NUM_PATTERNS do
    for y=1,NUM_TRACKS do
      for x=1,MAX_PATTERN_LENGTH do
        io.write(self:trig_level(patternno, x, y) .. "\n")
      end
    end
  end
  io.close(fd)
end

function Sequencer:load_patterns()
  if self._is_mod then return end
  local fd=io.open(norns.state.data .. PATTERN_FILE,"r")
  if fd then
    io.input(fd)
    for patternno=1,NUM_PATTERNS do
      for track=1,NUM_TRACKS do
        for step=1,MAX_PATTERN_LENGTH do
          self:set_trig(patternno, step, track, tonumber(io.read()) or 0)
        end
      end
    end
    io.close(fd)

    -- set up our local state in a way that indicates we don't need to reset the grid
    -- (see set_grids_xy)
    self.grids_x = params:get("cy_grids_pattern_x")
    self.grids_y = params:get("cy_grids_pattern_y")
    self._euclidean_kick = params:get(EuclideanUI.param_id_prefix_for_track(1).."_euclidean_enabled") == 2
    self._euclidean_snare = params:get(EuclideanUI.param_id_prefix_for_track(2).."_euclidean_enabled") == 2
    self._euclidean_hat = params:get(EuclideanUI.param_id_prefix_for_track(3).."_euclidean_enabled") == 2
  end
end

function Sequencer.u8mix(a, b, mix)
  -- Roughly equivalent to ((mix * b + (255 - mix) * a) >> 8), if this is too non-performant
  return util.round(((mix * b) + ((255 - mix) * a)) / 255)
end

function Sequencer:set_grids_xy(patternno, x, y, force)
  -- Short-circuit this expensive operation if there's no change
  local euclidean_kick = params:get(EuclideanUI.param_id_prefix_for_track(1).."_euclidean_enabled") == 2
  local euclidean_snare = params:get(EuclideanUI.param_id_prefix_for_track(2).."_euclidean_enabled") == 2
  local euclidean_hat = params:get(EuclideanUI.param_id_prefix_for_track(3).."_euclidean_enabled") == 2
  if (
    not force
    and x == self.grids_x and y == self.grids_y
    and euclidean_kick == self._euclidean_kick
    and euclidean_snare == self._euclidean_snare
    and euclidean_hat == self._euclidean_hat
 ) then
    return
  end
  -- The DrumMap is at 32nd-note resolution,
  -- so we'll want to set different triggers depending on our desired grid resolution
  local grid_resolution = self:_grid_resolution()
  local step_offset_multiplier = math.floor(32/grid_resolution)
  local pattern_length = self:get_pattern_length()
  -- Chose four drum map nodes based on the first two bits of x and y
  local i = math.floor(x / 64) + 1 -- (x >> 6) + 1
  local j = math.floor(y / 64) + 1 -- (y >> 6) + 1
  local a_map = DrumMap.map[j][i]
  local b_map = DrumMap.map[j + 1][i]
  local c_map = DrumMap.map[j][i + 1]
  local d_map = DrumMap.map[j + 1][i + 1]
  for track=1,3 do
    local euclidean_mode = params:get(EuclideanUI.param_id_prefix_for_track(track).."_euclidean_enabled") == 2
    if not euclidean_mode then
      local track_offset = ((track - 1) * DrumMap.PATTERN_LENGTH)
      for step=1,pattern_length do
        local step_offset = (((step - 1) * step_offset_multiplier) % DrumMap.PATTERN_LENGTH) + 1
        local offset = track_offset + step_offset
        local a = a_map[offset]
        local b = b_map[offset]
        local c = c_map[offset]
        local d = d_map[offset]
        -- Crossfade between the values at the chosen drum nodes depending on the last 6 bits of x and y
        local x_xfade = (x * 4) % 256 -- x << 2
        local y_xfade = (y * 4) % 256 -- y << 2
        local trig_level = Sequencer.u8mix(Sequencer.u8mix(a, b, y_xfade), Sequencer.u8mix(c, d, y_xfade), x_xfade)
        self:set_trig(patternno, step, track, trig_level)
      end
    end
  end
  self.grids_x = x
  self.grids_y = y
  self._euclidean_kick = euclidean_kick
  self._euclidean_snare = euclidean_snare
  self._euclidean_hat = euclidean_hat
end

function Sequencer:recompute_euclidean_for_track(track)
  local eucl_mode_param_id = "cy_"..track.."_euclidean_enabled"
  local enabled = params:get(eucl_mode_param_id) == 2
  if not enabled then return end

  local param_id_prefix = EuclideanUI.param_id_prefix_for_track(track)
  local trigs = params:get(param_id_prefix.."_euclidean_trigs")
  local length = params:get(param_id_prefix.."_euclidean_length")
  local rotation = params:get(param_id_prefix.."_euclidean_rotation")
  local pattern = Euclidean.get_pattern(trigs, length, rotation)
  local patternno = self:_get_pattern_number()
  local master_pattern_length = self:get_pattern_length()
  for step=1,master_pattern_length do
    -- Loop the euclidean pattern
    local pattern_index = (step - 1) % #pattern + 1
    self:set_trig(patternno, step, track, pattern[pattern_index] and 255 or 0)
  end
end

function Sequencer:_clock_tick()
  while true do
    clock.sync(self._clock_sync_resolution)
    self:tick()
  end
end

function Sequencer:tick()
  local cut_quant = false
  if not self._is_mod then
    cut_quant = params:get("cy_cut_quant") == 1
  end
  if self.queued_playpos and cut_quant then
    self.ticks_to_next = 0
    self._raw_ticks = 0
  end

  -- Also track the swing-independent number of ticks for midi clock out messages
  local grid_resolution = self:_grid_resolution()
  local midi_ppqn_divisor = grid_resolution/4
  if (not self._raw_ticks) or (self._raw_ticks % midi_ppqn_divisor) == 0 then
    MidiOut:send_ppqn_pulse()
  end
  if (not self._raw_ticks) or (self._raw_ticks == 0) then
    self._raw_ticks = ppqn
  end
  self._raw_ticks = self._raw_ticks - 1

  if (not self.ticks_to_next) or self.ticks_to_next == 0 then
    local patternno = self:_get_pattern_number()
    -- Update the triggers to match the selected MI-Grids X and Y parameters
    self:set_grids_xy(patternno, params:get("cy_grids_pattern_x"), params:get("cy_grids_pattern_y"))
    -- If there's a queued cut, set it and forget it
    local previous_playpos = self.playpos
    if self.queued_playpos then
      self.playpos = self.queued_playpos
      self.queued_playpos = nil
    else
      -- otherwise, advance by a beat
      self.playpos = (self.playpos + 1) % self:get_pattern_length()
    end
    if self.playpos == 0 then
      -- At the start of the pattern, figure out how much to bump up our trigger level by based on the chaos parameter
      for track=1,self.num_tracks do
        local chaos = math.floor(params:get("cy_pattern_chaos") * 255 / 100 / 4)
        local random_byte = math.random(0, 255)
        self._part_perturbations[track] = math.floor(random_byte * chaos / 256)
      end
      -- also, reset shuffle vars
      self._shuffle_basis_index = params:get("cy_shuffle_basis") - 1
      self._shuffle_feel_index = params:get("cy_shuffle_feel")
      self._ppqn_error = 0
    end

    MidiOut:turn_off_active_notes(self.num_tracks)
    local ts = {}
    local velocities = {}
    for y=1,self.num_tracks do
      local trig_level = self:trig_level(patternno, self.playpos+1, y)
      -- The original MI Grids algorithm makes it possible that a track would trigger on every beat
      -- If density > ~77%, chaos at 100%, and the random byte rolls full (or if density is higher, chaos can be lower, etc.)
      -- This seems... wrong to me, so I've made sure that if the trigger map says zero, that means no triggers happen.
      trig_level = trig_level ~= 0 and util.clamp(trig_level + self._part_perturbations[y], 0, 255) or 0
      local threshold
      local param_id = "cy_"..y.."_density"
      threshold = 255 - util.round(params:get(param_id) * 255 / 100)
      if trig_level > threshold then
        ts[y] = 1
        velocities[y] = trig_level
        if self._engine_enabled then
          -- Compute the sample volume. Max out at 192
          -- This param name comes from Ack
          local max_vol = params:get(y.."_vol")
          local sample_velocity = velocities[y] > 192 and 192 or velocities[y]
          local engine_vol = MIN_ENGINE_VOL + ((max_vol - MIN_ENGINE_VOL) * (sample_velocity/192))
          engine.volume(y-1, engine_vol)
        end
      else
        ts[y] = 0
        velocities[y] = 0
      end
    end
    -- Technically this should go inside
    if self._engine_enabled then
      -- TODO: don't send trigs for tracks beyond self.num_tracks
      -- (doesn't matter until non-mod usage can have a diff number of tracks)
      engine.multiTrig(ts[1], ts[2], ts[3], ts[4], ts[5], ts[6], ts[7], 0)
    end
    if MidiOut:is_midi_out_enabled() then
      for y=1,self.num_tracks do
        MidiOut:note_on(y, ts[y] * math.floor(velocities[y] / 2))
      end
    end
    if CrowIO:is_crow_out_enabled() then
      for crow_out=1,CrowIO:num_outs() do
        local y = params:get("cy_crow_out_"..crow_out.."_track")
        if ts[y] == 1 then
          CrowIO:gate_on(crow_out)
        end
      end
    end
    if self._action then
      for y=1,self.num_tracks do
        self._action(self, y, ts[y], velocities[y])
      end
    end

    if previous_playpos ~= -1 or self.playpos ~= -1 then
      UI.grid_dirty = true
    end
    self.ticks_to_next = self:_get_ticks_to_next()
    UI.screen_dirty = true
  end
  self.ticks_to_next = self.ticks_to_next - 1
end

function Sequencer:_grid_resolution()
  local param_grid_resolution = params:get("cy_grid_resolution")
  if param_grid_resolution == 1 then return 4 end
  if param_grid_resolution == 2 then return 8 end
  if param_grid_resolution == 3 then return 16 end
  return 32
end

function Sequencer:get_pattern_length_beats()
  return self:get_pattern_length() * (4 / self:_grid_resolution())
end

function Sequencer:_update_clock_sync_resolution()
  self._clock_sync_resolution = 4/ppqn/self:_grid_resolution()
end

function Sequencer:_is_even_side_swing()
  local grid_resolution = self:_grid_resolution()
  -- If resolution is quarters, we don't swing
  if grid_resolution == 4 then return nil end
  -- If resolution is 16th or higher, we do 16th note swing. At 8th notes, we do 8th note swing
  local playpos = self.playpos
  local divisor = math.ceil(grid_resolution/16)
  playpos = math.floor(playpos/divisor)
  -- If we're in an odd meter, we don't swing the last beat
  local pattern_length = math.floor(self:get_pattern_length()/divisor)
  if pattern_length % 2 == 1 and playpos == pattern_length - 1 then
    return nil
  end
  return playpos % 2 == 0
end

local drunk_map = {
  {2/9, 3/9, 2/9, 2/9, 2/9, 3/9, 2/9, 2/9},
  {2/7, 2/7, 2/7, 1/7, 2/7, 2/7, 2/7, 1/7},
  {1/5, 2/5, 1/5, 1/5, 1/5, 2/5, 1/5, 1/5},
  {1/6, 3/6, 1/6, 1/6, 1/6, 3/6, 1/6, 1/6},
  {1/8, 4/8, 2/8, 1/8, 1/8, 4/8, 2/8, 1/8},
  {1/9, 5/9, 2/9, 1/9, 1/9, 5/9, 2/9, 1/9},
}
local smooth_map = {
  {5/18, 5/18, 4/18, 4/18, 5/18, 5/18, 4/18, 4/18},
  {4/14, 4/14, 3/14, 3/14, 4/14, 4/14, 3/14, 3/14},
  {3/10, 3/10, 2/10, 2/10, 3/10, 3/10, 2/10, 2/10},
  {2/6, 2/6, 1/6, 1/6, 2/6, 2/6, 1/6, 1/6},
  {5/16, 5/16, 3/16, 3/16, 5/16, 5/16, 3/16, 3/16},
  {6/18, 7/18, 3/18, 2/18, 6/18, 7/18, 3/18, 2/18},
}
local heavy_map = {
  {4/9, 2/9, 2/9, 1/9, 4/9, 2/9, 2/9, 1/9},
  {3/7, 1/7, 2/7, 1/7, 3/7, 1/7, 2/7, 1/7},
  {2/5, 1/5, 1/5, 1/5, 2/5, 1/5, 1/5, 1/5},
  {3/6, 1/6, 1/6, 1/6, 3/6, 1/6, 1/6, 1/6},
  {4/8, 1/8, 2/8, 1/8, 4/8, 1/8, 2/8, 1/8},
  {5/9, 1/9, 2/9, 1/9, 5/9, 1/9, 2/9, 1/9},
}
local clave_map = {
  {2/9, 3/9, 2/9, 2/9, 3/9, 2/9, 2/9, 2/9},
  {2/7, 2/7, 1/7, 2/7, 2/7, 1/7, 2/7, 2/7},
  {1/5, 2/5, 1/5, 1/5, 2/5, 1/5, 1/5, 1/5},
  {3/12, 4/12, 2/12, 3/12, 4/12, 2/12, 3/12, 3/12},
  {3/16, 6/16, 3/16, 4/16, 5/16, 3/16, 4/16, 4/16},
  {4/18, 7/18, 3/18, 4/18, 7/18, 2/18, 5/18, 4/18},
}
local shuffle_feels = {
  drunk_map,
  smooth_map,
  heavy_map,
  clave_map
}

function Sequencer:_get_ticks_to_next()
  local pattern_length = self:get_pattern_length()
  local grid_resolution = self:_grid_resolution()
  local is_simple_swing = self._shuffle_basis_index == 0
  local num_beats = (pattern_length / grid_resolution) * 4
  local num_fallback_to_simple = (num_beats - math.floor(num_beats)) * 4
  local use_shuffle = self.playpos < pattern_length - num_fallback_to_simple
  if not is_simple_swing and use_shuffle then
    local playpos_per_shuffle_cell = grid_resolution / 16
    local playpos_per_shuffle_row = 8
    local playpos_mod = self.playpos % (playpos_per_shuffle_cell * playpos_per_shuffle_row)
    local shuffle_beat_index_min = math.floor(playpos_mod / playpos_per_shuffle_cell) + 1
    local shuffle_beat_index_max = math.max(shuffle_beat_index_min, math.floor((playpos_mod + 1) / playpos_per_shuffle_cell))
    local shuffle_map = shuffle_feels[self._shuffle_feel_index]
    local multiplier = 0
    for shuffle_beat_index=shuffle_beat_index_min,shuffle_beat_index_max do
      multiplier = multiplier + shuffle_map[self._shuffle_basis_index][shuffle_beat_index]
    end
    multiplier = multiplier / (shuffle_beat_index_max - shuffle_beat_index_min + 1)
    local exact_ppqn = 4 * ppqn * multiplier
    local rounded_ppqn = util.round(exact_ppqn + self._ppqn_error)
    self._ppqn_error = exact_ppqn + self._ppqn_error - rounded_ppqn
    return rounded_ppqn
  end

  -- Figure out how many ticks to wait for the next beat, based on swing
  local is_even_side_swing = self:_is_even_side_swing()
  if is_even_side_swing == nil then
    return ppqn
  end
  if is_even_side_swing then
    return self.even_ppqn
  end
  return self.odd_ppqn
end

local basis_to_swing_amt = {
  0,
  100 / (ppqn*0.75) * (((2 * ppqn) * (5/9)) - ppqn),
  100 / (ppqn*0.75) * (((2 * ppqn) * (4/7)) - ppqn),
  100 / (ppqn*0.75) * (((2 * ppqn) * (3/5)) - ppqn),
  100 / (ppqn*0.75) * (((2 * ppqn) * (4/6)) - ppqn),
  100 / (ppqn*0.75) * (((2 * ppqn) * (5/8)) - ppqn),
  100 / (ppqn*0.75) * (((2 * ppqn) * (6/9)) - ppqn),
}

function Sequencer:update_swing()
  local swing_amount
  if params:get("cy_shuffle_basis") == 1 then
    swing_amount = params:get("cy_swing_amount")
  else
    swing_amount = basis_to_swing_amt[params:get("cy_shuffle_basis")]
  end
  local swing_ppqn = ppqn*swing_amount/100*0.75
  self.even_ppqn = util.round(ppqn+swing_ppqn)
  self.odd_ppqn = (2 * ppqn) - self.even_ppqn
end

function Sequencer:has_pattern_file()
  return util.file_exists(norns.state.data .. PATTERN_FILE)
end

return Sequencer
