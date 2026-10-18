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
- ``Group``
- ``ForEach``
- ``LazyVGrid``
- ``GridItem``
- ``ScrollView``
- ``ScrollViewReader``
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

### Controls and Forms

- ``Button``
- ``ButtonRole``
- ``Toggle``
- ``TextField``
- ``SecureField``
- ``TextEditor``
- ``Slider``
- ``Stepper``
- ``Picker``
- ``Form``
- ``FormField``
- ``FormSection``

### Collections and Presentation

- ``List``
- ``Table``
- ``TableColumn``
- ``TableColumnBuilder``
- ``TableColumns``
- ``OutlineGroup``
- ``DisclosureGroup``
- ``TabView``
- ``Tab``
- ``Menu``
- ``MenuItem``
- ``MenuShortcut``

### Modal Presentation

- ``View/sheet(isPresented:content:)``
- ``View/alert(_:isPresented:actions:message:)``
- ``View/confirmationDialog(_:isPresented:actions:message:)``

### Drawing and Appearance

- ``Canvas``
- ``Image``
- ``ImageView``
- ``Style``
- ``Color``
- ``Border``
- ``Edge``
- ``EdgeInsets``
- ``Alignment``
- ``HorizontalAlignment``
- ``VerticalAlignment``
- ``FrameLimit``

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
- ``PaddingView``
- ``SheetView``
- ``StyledView``
- ``SubmitView``
- ``TaskView``
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
