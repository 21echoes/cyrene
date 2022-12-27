-- Make sure there's only one copy
if _MidiOut ~= nil then
  return _MidiOut
end

local MidiOut = {}
local m = midi.connect()
local MAX_NUM_TRACKS = 7
local active_midi_notes = {}
local DEFAULT_NOTES = {
  -- General MIDI standard
  36, -- Kick
  38, -- Snare
  42, -- Closed hi-hat
  46, -- Open hi-hat
  70, -- Maraca
  37, -- Rimshot
  63, -- High Conga
}

function MidiOut:add_params(num_tracks, arcify, is_mod)
  params:add_group("MIDI", 1 + (num_tracks * 2))
  params:add_option("cy_midi_out", "Send MIDI?", {"Off", "On"}, is_mod and 1 or 2)
  for track=1,num_tracks do
    local note_param_id = "cy_"..track.."_midi_note"
    params:add_number(note_param_id, track..": midi note", 0, 127, DEFAULT_NOTES[track])
    if arcify then arcify:register(note_param_id) end
    local chan_param_id = "cy_"..track.."_midi_chan"
    params:add_number(chan_param_id, track..": midi chan", 1, 16, 1)
    if arcify then arcify:register(chan_param_id) end
  end
end

function MidiOut:is_midi_out_enabled(track, velocity)
  return params:get("cy_midi_out") == 2
end

function MidiOut:note_on(track, velocity)
  if not self:is_midi_out_enabled() then return end
  m:note_on(
    params:get("cy_"..track.."_midi_note"),
    velocity,
    params:get("cy_"..track.."_midi_chan")
  )
  active_midi_notes[track] = velocity
end

function MidiOut:turn_off_active_notes(_num_tracks)
  local num_tracks = _num_tracks or MAX_NUM_TRACKS
  for track=1,num_tracks do
    if active_midi_notes[track] ~= 0 then
      m:note_off(
        params:get("cy_"..track.."_midi_note"),
        active_midi_notes[track],
        params:get("cy_"..track.."_midi_chan")
      )
      active_midi_notes[track] = 0
    end
  end
end

function MidiOut:start_at_beginning(track, velocity)
  if self:is_midi_out_enabled() then
    m:start()
  end
end

function MidiOut:stop(track, velocity)
  if self:is_midi_out_enabled() then
    m:stop()
  end
end

function MidiOut:continue(track, velocity)
  if self:is_midi_out_enabled() then
    m:continue()
  end
end

function MidiOut:send_ppqn_pulse()
  if self:is_midi_out_enabled() then
    m:clock()
  end
end

-- Make sure there's only one copy
if _MidiOut == nil then
  _MidiOut = MidiOut
end

return _MidiOut
