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

Explore related views in <doc:ViewGallery>.
