# Contributing to Twill

Thanks for your interest in Twill. Bug reports, ideas, documentation improvements, tests, and code contributions are welcome. You do not need to know the entire framework to help.

Twill is still in early development, so public APIs and implementation details may change. Before starting a large feature or an architectural change, open an issue to discuss the problem and approach. For small fixes and documentation changes, feel free to open a pull request directly.

## Before you start

Check the existing [issues](https://github.com/philprime/Twill/issues) and [pull requests](https://github.com/philprime/Twill/pulls) to see whether someone is already working on the same thing. The [documentation index](Docs/README.md) links to the architecture, state, and interaction contracts. Reading the relevant contract first will help keep a change consistent with the rest of the framework.

If you find a bug, please include the Twill revision, Swift version, operating system, steps to reproduce, what you expected, and what happened instead. A small reproduction or failing test is especially helpful. For feature requests, describe the use case and what the current API makes difficult.

## Set up your environment

Twill uses Swift 6.4 or later and [Just](https://just.systems/) for development commands. On macOS, install Just and run the setup recipe from the repository root:

```bash
brew install just
just setup
```

On Linux, install Swift, Just, Bash, SwiftLint, dprint, and actionlint through your preferred package managers, then run `swift package resolve`. See the [development guide](Docs/DEVELOPMENT.md) for toolchain requirements, available recipes, and Linux or container options.

## Make a change

Keep pull requests focused on one problem. For behavior changes and bug fixes, add a focused failing test before changing production code. Cover the behavior you changed, including cleanup and error paths when applicable. Place tests in the appropriate unit or integration test target. Examples are manual playgrounds, not substitutes for tests.

Follow the existing Swift style and the relevant [architecture](Docs/ARCHITECTURE.md), [state](Docs/STATE.md), and [interaction](Docs/INTERACTION.md) contracts. If a change affects those contracts, update the corresponding documentation. Avoid unrelated refactoring in the same pull request.

## Run checks

Start with the narrowest relevant test, then run the full checks from the repository root:

```bash
just test
just test-integration
just analyze
just build
```

For Swift changes, run `just format` before the final `just analyze`. The [development guide](Docs/DEVELOPMENT.md) explains how to run release checks and cross-platform verification. If a check cannot run locally, say which one and why in your pull request.

## Open a pull request

Explain the problem, summarize your solution, and include the tests or checks you ran. Link a related issue when there is one. If your change affects terminal behavior or the public API, show how a user would observe it. Draft pull requests are fine for work in progress.

Please be open to review and follow-up changes. Review is a conversation about making Twill better, and a maintainer may suggest a smaller scope or a different approach. Contributions are subject to the repository's [license](LICENSE.md).
