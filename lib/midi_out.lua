-- Make sure there's only one copy
if _MidiOut ~= nil then
  return _MidiOut
end

local MidiOut = {}
local m = midi.connect()
local NUM_TRACKS = 7
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

function MidiOut:add_params()
  params:add_group("MIDI", 1 + (NUM_TRACKS * 2))
  params:add_option("midi_out", "Send MIDI?", {"Off", "On"}, 2)
  for track=1,NUM_TRACKS do
    params:add_number("track"..track.."_midi_note", track..": midi note", 0, 127, DEFAULT_NOTES[track])
    params:add_number("track"..track.."_midi_chan", track..": midi chan", 1, 16, 1)
  end
end

function MidiOut:is_midi_out_enabled(track, velocity)
  return params:get("midi_out") == 2
end

function MidiOut:note_on(track, velocity)
  if not self:is_midi_out_enabled() then return end
  m:note_on(
    params:get("track"..track.."_midi_note"),
    velocity,
    params:get("track"..track.."_midi_chan")
  )
  active_midi_notes[track] = velocity
end

function MidiOut:turn_off_active_notes()
  for track=1,NUM_TRACKS do
    if active_midi_notes[track] ~= 0 then
      m:note_off(
        params:get("track"..track.."_midi_note"),
        active_midi_notes[track],
        params:get("track"..track.."_midi_chan")
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
