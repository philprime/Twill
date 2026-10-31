# ``Menu``

## Preview

An open menu, including a shortcut and disabled action. Enter opens or activates; arrows navigate; Escape dismisses.

![Menu terminal preview: An open menu, including a shortcut and disabled action. Enter opens or activates; arrows navigate; Escape dismisses.](preview-Menu)

## Compose Actions

```swift
Menu("Actions") {
    Button(saveCommand)
    Button("Delete", role: .destructive) { delete() }
        .disabled(selection == nil)
        .keyboardShortcut(.d)
}

Menu {
    ForEach(commands) { command in Button(command) }
} label: {
    Text("Actions").bold()
}
```

Menus store concretely typed opener labels and ordinary view-builder content. The concrete type is `Menu<Label, Content>`. Titled menus also title their action panel. Conditional content and keyed collections use normal mounted identity and state rules.

Buttons supply actions, roles, inherited disabled eligibility, and keyboard shortcuts. Menu labels append shortcut hints and disabled status using current mounted metadata. A shortcut on a container of independent controls does not assign either action a hint. Focused Enter and shortcuts share action-before-dismissal ordering, while label handlers keep first refusal. Escape dismisses without leaking keys to underlying content, and dismissal restores the opener's focus. Empty or entirely disabled menus still dismiss safely.

Dynamic content updates retain keyed rows and valid focus. Removing an action uses ordinary focus fallback and owned-work cleanup. Unchanged output and independent timeline deadlines remain unaffected by menu presentation.

## Separators and Submenus

Insert `Divider()` for a passive horizontal separator, and nest another `Menu` to create a submenu. Submenu labels show a direction marker. Enter or Right opens an eligible focused submenu, while Escape or Left returns one level and restores its opener. Label handlers retain first refusal, and disabled submenus are skipped during traversal.

Each level owns its key scope, so shortcuts in parent or sibling menus cannot activate through the child. Selecting a leaf action dismisses the menu chain and restores the original opener. Unrelated ordinary sheets and dialogs retain their presentation lifetime. Dynamic submenu removal falls back to a valid parent control without retaining the removed branch. Parent label timelines retain their independent phases while child menus are presented.

Explore related views in <doc:ViewGallery>.
