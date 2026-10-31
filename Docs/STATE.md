# State and identity

Collection selection IDs are application-owned values, distinct from effective visible selection. A selection policy resolves those IDs against current visible data without normalizing the binding. Nil, missing, hidden, and empty cases are resolved by `SelectionPolicy`; changing data or policy retains keyed row identity and unrelated schedules. Detail views can use the same pure resolver, including expansion-aware hierarchy resolution. Keyboard behavior is defined in [Interaction](INTERACTION.md).

Twill keeps view values as declarative descriptions. Mounted nodes own persistent state, identity, and cached presentation. State changes remain on the UI actor and request presentation without exposing an invalidation method to callers.

## State ownership

`@State` stores its initial value when its owning view is mounted. Subsequent view values with the same mounted identity reuse that value rather than reinitializing it. Removing the owner releases its state; remounting creates new state from the initial value. State used across navigation belongs in an ancestor that remains mounted.

Writing `@State` invalidates the affected content. The host coalesces multiple writes before presentation and writes nothing when the resulting frame is unchanged. Unrelated timeline deadlines remain intact. View bodies describe content and do not own timers or terminal output.

Viewport memory belongs to mounted identity, independently of the bound content value and keyboard focus. Compatible parent updates retain it, while identity replacement creates fresh memory. Remembered focus references are weak so they cannot keep removed content alive. Frame caches retain only descendant placements and scalar layout summaries, not their owning node or pass-local measurement callbacks.

`@Binding` provides read/write access to a value owned by another node. Writing through a binding updates that owner and triggers the same invalidation as a direct state write. Bindings do not extend the owner's lifetime or create independent storage. Shared mutable values use bindings; commands such as navigation use actions.

## Asynchronous view work

Attach `.task` to a view to start an asynchronous, UI-actor-isolated action when that view mounts. The action can update `@State` to present a result. Its default priority is `.userInitiated`; pass `priority:` to choose another priority. Handle thrown errors within the action because the modifier accepts a nonthrowing closure.

The mounted node owns the task. Parent reevaluation and state updates that preserve the node's identity do not start another task. Replacing or removing the node cancels its task; remounting starts a new one. If a node disappears before its action begins, that action is skipped. Cancellation is cooperative, so long-running actions must respond to cancellation. On application shutdown, outstanding view tasks are cancelled and joined before terminal resources are restored. A task that does not finish after cancellation can delay shutdown.

## Identity and reconciliation

Structural position and concrete view type determine identity for ordinary children. Compatible descriptions update their mounted nodes while retaining state. Switching conditional branches or changing a child's type replaces the affected subtree. An absent optional branch retains its position so later siblings do not inherit its state. Removing a branch releases its children and their pending deadlines.

An explicit `.id(_:)` boundary keys its content within its structural position. Equal IDs preserve the mounted subtree while updating its inputs. A changed ID unmounts the old subtree and mounts fresh content, discarding its state, focus memory, viewport offsets, and deadlines. Returning to a removed ID does not restore its former state. Modifiers outside the boundary retain their own identity. Tasks owned inside a replaced boundary are cancelled, and the host retains their unfinished cleanup until it can join them during shutdown.

Dynamic collections reconcile children by stable element ID rather than current index. Reordering or inserting elements preserves state for IDs that remain mounted. Removing an ID releases its state. An ID reused for a different logical element incorrectly inherits state, so callers must choose stable IDs.

Selection is independent of mounted child identity and keyboard focus. A collection control may store a selected element ID in an ancestor so selection survives screen changes. If that ID is absent from the visible collection, the first visible element is the effective selection until the user selects another; the stored ID remains unchanged. An empty collection has neither an effective selection nor an activation target.

[Interaction](INTERACTION.md) defines which focused control receives input and how editing, modal scopes, and key handlers affect state.

## Presentation payload identity

An optional identifiable payload can own modal presence for sheets, alerts, and confirmations. A non-nil value presents content and nil ends its mounted lifetime. Updated values with the same ID retain the content's state and owned work; a changed ID replaces the keyed subtree. Dismissing and re-presenting starts a new lifetime even if the ID repeats. The underlying view retains its independent state, identity, and schedules throughout presentation. Keyboard isolation and focus restoration follow the interaction contract.

## Observe Equatable Values

`.onChange(of:initial:_:)` retains a typed observation cache in mounted state. Initial delivery is opt-in and supplies current/current on the first eligible update. Otherwise mounting establishes the baseline without a callback.

Delivery follows the complete reconciliation/body-evaluation pass. Changes coalesce from the last delivered baseline to the latest value and action. Equal values, including a return to the baseline before delivery, produce no callback. Equality follows the supplied value's Equatable semantics rather than hashing or deep copying.

Inactive retained destinations defer delivery and coalesce until presentation eligibility returns, including modifiers surrounding a destination. An initial callback deferred this way uses current/current on activation. Removal cancels pending delivery and releases retained values/actions. Pending registrations do not extend node lifetime or add timer deadlines.

Callbacks run on the UI actor and may write state. Those writes request later mounted passes rather than recursive delivery. Cached layout/resize does not deliver observations. Before routing another input key, the host settles newly requested content passes while retaining one coalesced presentation. Stopping from a callback cancels later delivery and prevents subsequent presentation or application key fallthrough.
