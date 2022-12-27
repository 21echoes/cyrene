local mod = require 'core/mods'
local matrix = require('matrix/lib/matrix')
local seq = require('cyrene/lib/sequencer')
local MidiOut = require('cyrene/lib/midi_out')
local CrowIO = require('cyrene/lib/crow_io')

local channels = {
    "cyrene_1_kick",
    "cyrene_2_snare",
    "cyrene_3_hat",
    "cyrene_4",
    "cyrene_5",
    "cyrene_6",
    "cyrene_7",
}

local function action(self, chan, trig, velocity)
    matrix:set(channels[chan].."_trig", trig)
    matrix:set(channels[chan].."_vel", velocity/255)
end

local cyrene_sequencer

local function pre_init()
    matrix:add_post_init_hook(function()
        if norns.state.name == "cyrene" then
            -- No need to add cyrene, we are already cyrene.
            return
        end

        -- Set up the "outputs": trigs and velocity for each of the first 3 tracks
        matrix:add_binary("cyrene_1_kick_trig", "Cyrene 1 (Kick)")
        matrix:add_binary("cyrene_2_snare_trig", "Cyrene 2 (Snare)")
        matrix:add_binary("cyrene_3_hat_trig", "Cyrene 3 (Hat)")
        matrix:add_binary("cyrene_4_trig", "Cyrene 4")
        matrix:add_binary("cyrene_5_trig", "Cyrene 5")
        matrix:add_binary("cyrene_6_trig", "Cyrene 6")
        matrix:add_binary("cyrene_7_trig", "Cyrene 7")
        matrix:add_unipolar("cyrene_1_kick_vel", "Cyrene 1 (Kick) Vel")
        matrix:add_unipolar("cyrene_2_snare_vel", "Cyrene 2 (Snare) Vel")
        matrix:add_unipolar("cyrene_3_hat_vel", "Cyrene 3 (Hat) Vel")
        matrix:add_unipolar("cyrene_4_vel", "Cyrene 4 Vel")
        matrix:add_unipolar("cyrene_5_vel", "Cyrene 5 Vel")
        matrix:add_unipolar("cyrene_6_vel", "Cyrene 6 Vel")
        matrix:add_unipolar("cyrene_7_vel", "Cyrene 7 Vel")

        -- Set up the sequencer
        local sequencer = seq:new(action, 7, true)
        sequencer:add_params()
        for track=1,sequencer.num_tracks do
            local group_name = "Track "..track
            if track == 1 then group_name = "Kick"
            elseif track == 2 then group_name = "Snare"
            elseif track == 3 then group_name = "Hi-Hat"
            end
            params:add_group(group_name, 5)
            sequencer:add_params_for_track(track)
        end
        MidiOut:add_params(sequencer.num_tracks, nil, true)
        CrowIO:add_params(sequencer.num_tracks, nil, true)
        -- defer_bang for all params with meaningful action side-effects
        -- (effectively, those that put the sequencer in the correct state)
        matrix:defer_bang("cy_grid_resolution")
        matrix:defer_bang("cy_shuffle_basis")
        matrix:defer_bang("cy_swing_amount")
        for track=1,sequencer.num_tracks do
            matrix:defer_bang("cy_"..track.."_euclidean_enabled")
            matrix:defer_bang("cy_"..track.."_euclidean_length")
            matrix:defer_bang("cy_"..track.."_euclidean_trigs")
            matrix:defer_bang("cy_"..track.."_euclidean_rotation")
        end
        clock.run(function()
            clock.sync(sequencer:get_pattern_length_beats())
            params:lookup_param("cy_play"):bang()
        end)
        sequencer:initialize()

        cyrene_sequencer = sequencer
    end)
end

mod.hook.register("script_pre_init", "cyrene pre init", pre_init)

mod.hook.register("script_post_cleanup", "stop cyrene", function()
    if cyrene_sequencer ~= nil then
        params:set("cy_play", 0)
        cyrene_sequencer = nil
    end
end)
