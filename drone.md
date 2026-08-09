Two very different link budgets are at play here, command/telemetry versus video, and that's why the answer splits hard.

**Best case: command + GPS telemetry, no or minimal video**

This is the easy case because a control/telemetry stream is a few hundred bits/sec to a few kbps. Low data rate means huge processing gain is available (FHSS or LoRa-style spreading), so the link tolerates much higher path loss than video ever will. With a mast-mounted high-gain antenna on the ground side and a simple whip on the drone, control and position telemetry can realistically hold to 30-50km line of sight, sometimes more, if terrain and radio horizon allow it. The dominant constraint stops being SNR and becomes physical line of sight (earth curvature, terrain masking). This is exactly why the Ukrainian relay mast architecture exists: push the ground antenna forward so it has LOS to the drone, then backhaul the low-rate control link to the rear operator over a separate high-gain hop.

**Best case: good video return**

Video eats bandwidth, analog FPV channels run 18-27MHz wide, digital HD systems (DJI O3, Walksnail, HDZero) need consistently high SNR across a wideband channel to avoid artifacting or complete dropout. That drives range down sharply compared to telemetry-only. Digital HD systems with a tracking directional antenna on the ground and decent power on the drone typically top out around 15-25km in genuinely clear LOS conditions before video degrades to unusable. Analog is generally worse, most setups fall apart past 10-15km even with a gain antenna, though analog degrades gracefully (noise in the picture) rather than digital's cliff-edge total loss. Video is also far more sensitive to multipath and polarization mismatch than telemetry, since a lost packet in an FHSS control link just gets retried, but a lost video frame is gone.

**Is it easy to lose signal with a Yagi**

Depends entirely on whether the Yagi is pointed at something moving.

As a fixed point-to-point backhaul antenna (mast to rear operator), a Yagi is excellent, aim once, it stays locked, narrow beamwidth (typically 20-40 degrees for a 10-16 element Yagi) is a feature there since it concentrates energy and rejects off-axis interference and jamming.

As the antenna tracking the drone itself, a Yagi is a liability. Narrow beamwidth means any drone maneuver outside that 20-40 degree cone breaks lock instantly, which is precisely why the operator is calling bearing corrections over the radio, they're manually walking the beam onto a moving target with a mechanically slewed or hand-adjusted mount. Wind-induced mast sway (visible in your images, that shroud is bell-mouthing significantly) also physically moves the boresight, causing intermittent dropout independent of drone motion. This is the operational reason panel/sector antennas or phased/patch tracker arrays are increasingly favored on the drone-facing side over a Yagi: wider beamwidth trades some gain for much better tolerance of target movement and mast vibration.

**Antenna types by role**

*Drone-side, TX (video/telemetry uplink to ground):*
- Cloverleaf or skew-planar wheel (circular polarized omni): standard FPV video TX, tolerates roll/pitch/yaw without deep nulls since polarization stays matched regardless of drone attitude
- Simple dipole/whip: control link uplink antenna, omnidirectional since drone orientation relative to ground station is unpredictable in flight

*Ground-side, RX facing the drone (mobile target, needs to track):*
- Patch/panel array with RF switching or true phased array (tracker antenna): electronically steered, no mechanical lag, best for maintaining lock on a maneuvering target
- Mechanically slewed panel or short Yagi on a servo mount: cheaper alternative, slower to react, adequate if drone flight profile is predictable (racetrack orbits, not aggressive evasive maneuvering)
- Circular polarized patch: matches the drone's cloverleaf TX polarization, avoids the polarization-mismatch fade a linear Yagi would suffer as the drone rolls

*Ground-side, backhaul (fixed point-to-point, mast to rear operator):*
- Yagi-Uda: high gain (10-16dBi), narrow beam, ideal since both ends are stationary once aimed
- Parabolic/grid dish: even higher gain for longer backhaul hops, but heavier, more wind load, and unforgiving of any mast movement, worse choice here given how much that mast is already swaying
- Log-periodic: if frequency agility across a wide band is needed to dodge jamming/interference, trades some gain for bandwidth flexibility

*General RX/TX for jam resistance:*
- Lower-gain, wider-beamwidth antennas paired with frequency hopping spread spectrum reduce vulnerability to direction-finding and narrowband jamming compared to a single high-gain fixed-beam antenna, which is a tradeoff against the pure range-maximization logic above. Ukrainian units are constantly balancing "more gain equals more range" against "more gain equals a more locatable and more easily nulled-out emitter."