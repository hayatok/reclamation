# Final-operation facility defense prototype

Unaccepted gameplay prototype following public 0.53. The first eligible, already-scheduled wave with at least 12 seconds of warning approaches one restored transmission facility. The existing enemy count, spawn coordinates, types, health, speed and combat damage are retained. Changing the route can change difficulty; ordinary earned-resource play and native visual acceptance remain pending.

Once that wave is dispatched, living enemies physically within five meters of the announced facility interrupt initial transmission. Accrued progress is retained and resumes immediately when the zone clears. Distant or unreachable enemies cannot interrupt it. Raiders engage nearby survivors or buildings, otherwise approach the facility using the existing bounded navigation scheduler. The site itself has no invented health or damage system. No garrison tax or mandatory extra waiting is added.

The existing status line names the threatened facility and countdown; the existing mission action focuses that facility. Interrupted progress and the instruction to clear its surroundings replace existing contextual lines. Missions one and two do not activate this behavior.

A remaining minimum-warning budget prevents the existing boss event from accelerating the announced wave to less than 12 seconds after its cue. This only limits acceleration; the original scheduled arrival is never delayed.

The controller and raider identity persist in validated checkpoints. Malformed state is rejected before the live world is cleared. Focused integration confirms matching ordinary/redirected wave contents and RNG, occupancy pause/resume, and a real checkpoint round trip. These controlled fixtures do not demonstrate strategic value or human enjoyment.

Design references: official Age of Empires IV victory conditions and Season One map notes distinguish destroying a base from holding geographically exposed objectives. Applying that lesson to restored infrastructure is this game's design hypothesis, not a claim about identical mechanics.

- https://www.ageofempires.com/news/quickstart-guide-age-of-empires-iv/
- https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/

Native controlled-frame review at 1180×737 confirms the existing countdown, focus action and interruption instruction are legible. These images stage warning/occupation on an archived army and are not ordinary-play or performance evidence. See `evidence/transmission_defense/review.json`.
