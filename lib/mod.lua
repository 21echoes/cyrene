local mod = require 'core/mods'
local matrix = require('matrix/lib/matrix')
local seq = require('cyrene/lib/sequencer')

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
        matrix:add_binary("cyrene_kick", "Cyrene Kick")
        matrix:add_binary("cyrene_snare", "Cyrene Snare")
        matrix:add_binary("cyrene_hat", "Cyrene Hat")
        matrix:add_unipolar("cyrene_kick_vel", "Cyrene Kick Vel")
        matrix:add_unipolar("cyrene_snare_vel", "Cyrene Snare Vel")
        matrix:add_unipolar("cyrene_hat_vel", "Cyrene Hat Vel")
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
        -- TODO: figure out why this is defered
        matrix:defer_bang("swing_amount")
        clock.run(function()
            -- TODO: figure out why we wait 8 beats before we consider playing
            clock.sync(8)
            params:lookup_param("cyrene_play"):bang()
        end);
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
