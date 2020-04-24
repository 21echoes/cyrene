# Coleman
A drummer in a box for norns. Based on Grids by Émilie Gillet

## UI & Controls
### Pattern page:
* E2 & E3 control pattern
* E1 adds randomness

### Density page:
* E1, E2, & E3 control hat, kick, snare respectively

### Basics page:
* E2 controls tempo
* E3 controls swing
* Hold K2 and tap K3 for tap tempo

## Requirements
* norns (200328 or later)
* the Ack engine

## Roadmap
* Basic re-implementation of the core MI Grids functionality
* Any track can swap from Grids mode to Euclid mode (which is also a mode in the original MI Grids)
* monome grid support:
  * Some sort of probability mode. whole grid is one track, x axis is beat #, y axis is the probability
  * Euclid tracks are just 0/1 probabilities, while gridseed shows the 8bit values rounded
    * They're still their 8bit values, we just show them on grid as rounded. If they are edited by the user, they get written to the live trigger set as their 3bit values
* More tracks (MI Grids only supports hat/kick/snare (with accents), so these would be without the Grids data and x/y functionality)
* Multi-sample mode: use multiple samples on the same track (e.g. two slightly different kick drums) for more realism
* Velocity / different volumes
* Non-4/4 meters
* MIDI out
