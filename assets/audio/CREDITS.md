# Audio credits

All files here are CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) or were synthesized for this project (also CC0).
Everything is rebuilt by `python3 -I tools/audio_build.py <downloads> assets/audio <report>`, where `<downloads>` holds the sources below (one folder per source, as named in the script).
All outputs are 22.05 kHz, mono WAV (3D and one-shots, imported as QOA) or stereo Ogg Vorbis (ambience beds).

## Sources (CC0)
- Kenney, "Impact Sounds" (https://kenney.nl/assets/impact-sounds), CC0 1.0
  - step_concrete_*, step_grass_*, step_wood_*: footstep_concrete/grass/wood_000-004, trimmed and normalized
  - step_asphalt_*: footstep_concrete, pitched down 12%, low-passed, with a short synthesized grit layer
  - step_paver_*: footstep_concrete, pitched up 7%, with a synthesized block-rattle click
  - npc steps reuse step_concrete_*
- Kenney, "Interface Sounds" (https://kenney.nl/assets/interface-sounds), CC0 1.0
  - ui_phone_open (open_001), ui_phone_close (close_001), ui_goal (confirmation_002)
- IgnasD, "High traffic road sounds" (https://opengameart.org/content/high-traffic-road-sounds), CC0
  - amb_avenue: crossfade loop, stereo by time offset; also the low-passed traffic layer inside amb_city
- Thimras, "Park ambiences" (https://opengameart.org/content/park-ambiences), CC0
  - amb_wind (park_ambience_wind, 30 s crossfade loop), bird_loop_b (park_ambience_birds, 30 s segment, high-passed)
- isaiah658, "Ambient Bird Sounds" (https://opengameart.org/content/ambient-bird-sounds), CC0
  - bird_loop_a (high-passed crossfade loop)
- StarNinjas, "Crowd Shouting/Speaking Ambience" (https://opengameart.org/content/crowd-shoutingspeaking-ambience), CC0
  - amb_crowd: low-passed at 1.9 kHz and level-compressed into a murmur, crossfade loop
- GGBotNet, "Car Sound Effects Pack (Low Quality)" (https://opengameart.org/content/car-sound-effects-pack-low-quality), CC0
  - sfx_engine_car (Car_Engine_Loop), sfx_engine_car_b (Car_Engine_Loop_2), sfx_engine_bus (Car_Engine_Loop_2 pitched down + synthesized sub rumble), sfx_horn_0 (Car_Horn)
- WuxiaScrub, "Helicopter SFX" (https://opengameart.org/content/helicopter-sfx), CC0
  - amb_heli (crossfade loop)

## Synthesized (tools/audio_build.py, CC0)
- amb_city: periodic shaped noise (seamless by construction) + low-passed traffic bed
- amb_siren: distant two-tone wail with outdoor reverb tail, 8 s loop
- sfx_horn_1..3: dual-tone car horns (taps and long press)
- sfx_brake_squeal, sfx_air_brake (bus), sfx_crossing_beep (accessible pedestrian signal)
- bird_maritaca_0..2 (flocks of parakeet screeches), bird_bemtevi_0..1 (three-note whistled call)
