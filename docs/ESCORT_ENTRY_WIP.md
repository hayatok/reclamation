# Explicit escort entry — development checkpoint

The existing follow order now has an explicit action in the combat selection panel. Choose Escort, then click/tap a friendly leader, including one already in the same selection. The leader retains its own order; eligible followers use the existing EscortOrders implementation. Ordinary right-click escort, movement speeds, attack behavior, and Q attack-move/W stop are unchanged.

The target-picking state can be cancelled without cancelling an already-issued escort. Selection changes and modals clear the transient state. Mobile entry resets stale range/order/add modes and enables the existing Cancel control. The existing detail strip and touch instruction line identify the next action. No new panel or formation/slowest-speed simulation was added.

Native desktop mouse review used the unmodified earned 720-second frontier save: select ten including the siege cart, press Escort, choose that selected cart, observe nine followers assigned, retain all ten selected, save with F6, and cancel a repeated target choice with Escape. Controlled headless checks passed leader preservation, invalid target rejection, selected-target assignment, cancellation/selection interruption, touch mode transition and actual save/reload. These fixtures do not establish physical-phone behavior.

Final small-screen native review and publication remain pending for this checkpoint. Public v0.43 is unchanged. The interrupted southeast-policy comparison is inconclusive and supplies no justification for changing enemies/resources or route balance.
