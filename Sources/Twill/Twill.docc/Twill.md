# ``Twill``

Build interactive terminal applications from declarative Swift views.

## Overview

Compose text, controls, collections, and custom cell drawings into a view hierarchy. Twill measures content in terminal cells, manages keyboard focus, and presents changes through an event-driven application runtime on macOS and Linux.

Start with <doc:GettingStarted>, then explore <doc:ViewGallery> to see rendered examples of the available views. Use the guides below to learn how state, layout, keyboard interaction, and scheduled work fit together.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ViewGallery>
- ``Application``
- ``View``
- ``ViewBuilder``

### Composition and Layout

- <doc:LayoutAndDrawing>
- ``Text``
- ``VStack``
- ``HStack``
- ``SplitView``
- ``Spacer``
- ``Divider``
- ``Group``
- ``ForEach``
- ``LazyVGrid``
- ``VGrid``
- ``GridItem``
- ``ScrollView``
- ``ScrollViewReader``
- ``ScrollIndicatorView``
- ``ScrollViewProxy``
- ``GroupBox``
- ``EmptyView``

### State and Identity

- <doc:ManagingState>
- ``State``
- ``Binding``

### Keyboard Interaction

- <doc:KeyboardInteraction>
- ``FocusState``
- ``KeyEvent``
- ``KeyModifiers``
- ``KeyPressResult``

### Commands and Key Hints

- ``Command``
- ``KeyHints``
- ``KeyboardShortcut``

### Controls and Forms

- ``Button``
- ``ButtonRole``
- ``ControlStyle``
- ``ControlAppearance``
- ``ControlState``
- ``ControlKind``
- ``ControlFocusEffect``
- ``Toggle``
- ``TextField``
- ``SecureField``
- ``TextEditingMode``
- ``TextEditor``
- ``Slider``
- ``Stepper``
- ``Picker``
- ``PickerPresentation``
- ``Form``
- ``FormField``
- ``FormSection``

### Collections and Presentation

- ``List``
- ``SelectionPolicy``
- ``Table``
- ``TableColumn``
- ``TableColumnWidth``
- ``TableColumnBuilder``
- ``TableColumns``
- ``OutlineGroup``
- ``DisclosureGroup``
- ``TabView``
- ``Tab``
- ``Menu``
- ``MenuItem``

### Modal Presentation

- ``View/sheet(isPresented:content:)``
- ``View/alert(_:isPresented:actions:message:)``
- ``View/confirmationDialog(_:isPresented:actions:message:)``

### Drawing and Appearance

- ``Canvas``
- ``PixelCanvas``
- ``Path``
- ``PixelPoint``
- ``PixelRect``
- ``PixelSize``
- ``PixelColor``
- ``Image``
- ``ImageView``
- ``Style``
- ``Color``
- ``SemanticColor``
- ``Theme``
- ``TextAttributes``
- ``Border``
- ``Edge``
- ``EdgeInsets``
- ``Alignment``
- ``HorizontalAlignment``
- ``VerticalAlignment``
- ``FrameLimit``
- ``SplitPaneWidth``
- ``ScrollIndicatorVisibility``
- ``Axis``

### Scheduled and Asynchronous Work

- <doc:ScheduledWork>
- ``TimelineView``
- ``TimelineViewContext``
- ``PeriodicTimelineSchedule``
- ``ProgressView``
- ``SpinnerStyle``
- ``TerminalProgress``

### View Modifiers and Builder Results

- ``BorderView``
- ``ConditionalContent``
- ``DisabledView``
- ``FocusableView``
- ``FocusedView``
- ``FrameView``
- ``KeyPressView``
- ``KeyboardShortcutView``
- ``PaddingView``
- ``SheetView``
- ``StyledView``
- ``SubmitView``
- ``TaskView``
- ``TextLayoutView``
- ``ViewList``

### Runtime Integration

- <doc:ApplicationLifecycle>
- ``RunLoop``
- ``DefaultRunLoop``
- ``RunLoopSource``
- ``RunLoopSourceRegistration``
- ``Timer``
- ``FileDescriptor``
- ``TerminalSize``
- ``TerminalError``
- ``InputSourceEvent``
- ``InputSource``
- ``KeyboardEventSource``
- ``TerminalSession``
- ``TerminalOutput``
- ``TerminalViewport``
- ``DefaultInputSource``
- ``DefaultKeyboardEventSource``
- ``DefaultTerminalSession``
- ``DefaultTerminalOutput``
- ``DefaultTerminalViewport``
