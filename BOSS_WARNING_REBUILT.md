# State-driven boss attack warning

Reproduction: an attack keeps windup1.4 seconds while the game is paused, but its transient pulse expires. Saving and opening a fresh scene also retains attack timing without recreating the pulse.

The warning now follows current living boss windup and fixed attack position directly. A thin cached boundary shows the full4.5m danger radius from the start and brightens with attack progress. It persists during pause and save/resume, clears at impact/death/end, and is independent of ordinary effect capacity. Visible-enemy/target filtering and conservative all-cell segment clipping prevent fog disclosure. No additional text or panel, and no gameplay/RNG/damage/timing changes.

Native controlled scene: paused and fresh-resumed warning remains visible; after28 simulation steps of.05sec, HQ1200→1080 and warning clears. Death clears it as well. Cached sync averaged21.64 microseconds over2000 native calls for one stationary boss without fog; not a frame-rate or browser benchmark. Focused state/cache/fog/lifecycle tests pass. Real Web/Mac/phone/GPU remain unverified.
