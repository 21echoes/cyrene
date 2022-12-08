local mod = require 'core/mods'
local matrix = require('matrix/lib/matrix')
local seq = require('cyrene/lib/sequencer')
local MidiOut = require('cyrene/lib/midi_out')
local CrowIO = require('cyrene/lib/crow_io')

local channels = {"cyrene_kick", "cyrene_snare", "cyrene_hat"}

local function action(self, chan, trig, velocity)
    matrix:set(channels[chan], trig)
    matrix:set(channels[chan].."_vel", velocity)
end

local cyrene_sequencer

local function pre_init()
    matrix:add_post_init_hook(function()
        if norns.state.name == "cyrene" then
            -- No need to add cyrene, we are already cyrene.
            return
        end

        -- Set up the "outputs": trigs and velocity for each of the first 3 tracks
        matrix:add_binary("cyrene_kick", "Cyrene Kick")
        matrix:add_binary("cyrene_snare", "Cyrene Snare")
        matrix:add_binary("cyrene_hat", "Cyrene Hat")
        matrix:add_unipolar("cyrene_kick_vel", "Cyrene Kick Vel")
        matrix:add_unipolar("cyrene_snare_vel", "Cyrene Snare Vel")
        matrix:add_unipolar("cyrene_hat_vel", "Cyrene Hat Vel")

        -- Set up the sequencer
        local sequencer = seq:new(action, 3, true)
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
        MidiOut:add_params(sequencer.num_tracks)
        CrowIO:add_params(sequencer.num_tracks)
        -- defer_bang for all params with meaningful action side-effects
        -- (effectively, those that put the sequencer in the correct state)
        matrix:defer_bang("grid_resolution")
        matrix:defer_bang("shuffle_basis")
        matrix:defer_bang("swing_amount")
        for track=1,sequencer.num_tracks do
            matrix:defer_bang(track.."_euclidean_enabled")
            matrix:defer_bang(track.."_euclidean_length")
            matrix:defer_bang(track.."_euclidean_trigs")
            matrix:defer_bang(track.."_euclidean_rotation")
        end
        clock.run(function()
            clock.sync(sequencer:get_pattern_length_beats())
            params:lookup_param("cyrene_play"):bang()
        end)
        sequencer:initialize()

        cyrene_sequencer = sequencer
    end)
end

mod.hook.register("script_pre_init", "cyrene pre init", pre_init)

mod.hook.register("script_post_cleanup", "stop cyrene", function()
    if cyrene_sequencer ~= nil then
        params:set("cyrene_play", 0)
        cyrene_sequencer = nil
    end
end)
