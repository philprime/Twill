## Latest Development Release

This rolling pre-release follows `main`. APIs may change between commits.

- **Commit**: {{COMMIT_SHA}}
- **Prepared**: {{BUILD_DATE}}
- **Version**: {{VERSION}}

### Swift Package Manager

Pin this exact revision for a reproducible dependency:

```swift
.package(url: "https://github.com/{{REPOSITORY}}.git", revision: "{{COMMIT_SHA}}")
```

Then add the `Twill` library product to your target dependencies.

This is a source release without standalone CLI binaries or installers. Prefer a versioned release when you need a stable dependency reference.

See the [commit history](https://github.com/{{REPOSITORY}}/commits/main) for recent changes.
