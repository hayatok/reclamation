# Optional desktop operation details

Fresh reconstructed change after 14f1c76e. No lost earlier implementation is claimed recovered.

At 1178 × 736, the expanded M3 panel is 262 × 249 pixels; clicking its header reduces it to 262 × 116. The current actionable goal, HQ HP, wave warning and dynamic progress/boss status remain outside the fold. Only the operation title and facility actions are hidden. Reopening is an explicit player action; objective updates never reopen it automatically. No save-format change or new mission rule.

Native desktop CUA mouse click accepted. Initial synthetic mouse-event attempts did not hit the letterboxed viewport correctly; they are not acceptance evidence. The interactive test waits for the real header click, then verifies collapse, three repeated toggles, objective update while folded, and identical serialized game state before/after the first click. Supplied images are the expanded and successfully collapsed states.

Mobile creates no desktop fold. Existing native synthetic-touch expanded-map flow passed again on landscape/portrait with selection/orders, cancellation, close/back and save/load. Font coverage passed. Real browser, actual phone, Mac and hardware GPU were not tested.
