# Coleman
A drummer in a box for norns. Based on Mutable Instruments Grids by Émilie Gillet and Step by Anton Hörnquist (jah)

Mutable Instruments Grids comes with 65,025 preset kick, snare, and hi-hat patterns. They are organized such that similar rhythms are positioned near each other in a two-dimentional grid, and the musician is able to select a position in that grid (and change that selection over time). These rhythms are then fed into a rather direct port of Step for norns, which is a Sample based, monome grid-enabled step sequencer using the Ack engine.

## UI & Controls
* E1 controls page

### Landing page:
* E2 controls tempo
* E3 controls swing
* K2+E2 controls volume
* K2 stops playback, K3 resumes playback
* K2 while stopped resets pattern to the first beat

### Pattern & Density page:
* K2 and K3 cycle through the sections of the page
* E2 & E3 control selected values (X/Y, Kick/Snare density, Hat density/Chaos)

### Grid (optional)
* Each row is a track, with the first 3 being kick, snare, and hi-hat respectively
* Each column is a beat in the sequence
* Clicking a key toggles whether or not the sample for that track will play on that beat
* Click on the last row jumps playback to the beat matching the clicked column

## Requirements
* norns
* the Ack engine
* grid optional (varibright encouraged, 8 or 16 wide)

## Roadmap
* Use the new norns global clock system once it's out
* Any track can swap from Grids mode to Euclid mode (which is also a mode in the original MI Grids)
* Hold K2 and tap K3 for tap tempo
* 32-step patterns instead of 16-step patterns (the MI Grids drum maps are 32 steps long)
  * This will require some sort of grid pagination
* Probability editing on the grid
  * In probability editing mode: whole grid is one track, x axis is beat #, y axis is the probability
  * In the trigger map our probabilities are 8bit values, so we'll have to show them on grid as rounded to 3bit values. If they are edited by the user, they get written to the trigger map as their 3bit values
* MI Grids-style "accent" support
* Multi-sample mode: use multiple samples on the same track (e.g. two slightly different kick drums) for more realism
* Velocity / different volumes
* Non-4/4 meters
* MIDI out
* Crow support
  * Map crow inputs to control a parameter (tempo, x, kick density, etc.)
  * Crow outputs are triggers for tracks 1 thru 4
