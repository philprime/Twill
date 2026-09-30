# State and identity

Twill keeps view values as declarative descriptions. Mounted nodes own persistent state, identity, and cached presentation. State changes remain on the UI actor and request presentation without exposing an invalidation method to callers.

## State ownership

`@State` stores its initial value when its owning view is mounted. Subsequent view values with the same mounted identity reuse that value rather than reinitializing it. Removing the owner releases its state; remounting creates new state from the initial value. State used across navigation belongs in an ancestor that remains mounted.

Writing `@State` invalidates the affected content. The host coalesces multiple writes before presentation and writes nothing when the resulting frame is unchanged. Unrelated timeline deadlines remain intact. View bodies describe content and do not own timers or terminal output.

`@Binding` provides read/write access to a value owned by another node. Writing through a binding updates that owner and triggers the same invalidation as a direct state write. Bindings do not extend the owner's lifetime or create independent storage. Shared mutable values use bindings; commands such as navigation use actions.

## Asynchronous view work

Attach `.task` to a view to start an asynchronous, UI-actor-isolated action when that view mounts. The action can update `@State` to present a result. Its default priority is `.userInitiated`; pass `priority:` to choose another priority. Handle thrown errors within the action because the modifier accepts a nonthrowing closure.

The mounted node owns the task. Parent reevaluation and state updates that preserve the node's identity do not start another task. Replacing or removing the node cancels its task; remounting starts a new one. If a node disappears before its action begins, that action is skipped. Cancellation is cooperative, so long-running actions must respond to cancellation. On application shutdown, outstanding view tasks are cancelled and joined before terminal resources are restored. A task that does not finish after cancellation can delay shutdown.

## Identity and reconciliation

Structural position and concrete view type determine identity for ordinary children. Compatible descriptions update their mounted nodes while retaining state. Switching conditional branches or changing a child's type replaces the affected subtree. An absent optional branch retains its position so later siblings do not inherit its state. Removing a branch releases its children and their pending deadlines.

Dynamic collections reconcile children by stable element ID rather than current index. Reordering or inserting elements preserves state for IDs that remain mounted. Removing an ID releases its state. An ID reused for a different logical element incorrectly inherits state, so callers must choose stable IDs.

Selection is independent of mounted child identity and keyboard focus. A collection control may store a selected element ID in an ancestor so selection survives screen changes. If that ID is absent from the visible collection, the first visible element is the effective selection until the user selects another; the stored ID remains unchanged. An empty collection has neither an effective selection nor an activation target.

[Interaction](INTERACTION.md) defines which focused control receives input and how editing, modal scopes, and key handlers affect state.
