# Contributing to CDOAuth1Kit

Thank you for your interest in contributing to CDOAuth1Kit! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Be respectful and constructive in all interactions with other contributors and maintainers.

## Reporting Issues

Before creating an issue, please:

1. Check existing issues to avoid duplicates
2. Use the GitHub issue template
3. Provide a minimal reproducible example
4. Include details about your environment (Xcode version, iOS/macOS version, Swift version)

For usage questions, please ask on [Stack Overflow](https://stackoverflow.com/questions/tagged/cdoauth1kit) using the `cdoauth1kit` tag.

## Submitting Changes

1. **Fork the repository** and create a branch for your changes
2. **Follow the code style** — the project uses SwiftLint and SwiftFormat
3. **Write tests** for new functionality or bug fixes
4. **Run the full test suite** locally before submitting
5. **Create a pull request** with a clear description of your changes

### Code Style

CDOAuth1Kit follows strict code style requirements:

- **SwiftLint** — Run `swiftlint` to check for style violations
- **SwiftFormat** — Run `swiftformat .` to auto-format code
- **Line length** — Warnings at 149 characters, errors at 200
- **Indentation** — 4 spaces

Run these commands before committing:

```bash
swiftformat .
swiftlint
swift build
swift test
```

### Testing

- All new public APIs must have corresponding tests
- All bug fixes must include a test demonstrating the fix
- Tests must use the Swift Testing framework (@Suite, @Test, #expect)
- Run `swift test` to verify all tests pass

### Documentation

- All public symbols must have `///` doc comments
- Doc comments must describe the purpose, parameters, and return value
- Use inline examples where helpful
- The CI job fails if any public symbol is undocumented

## Pull Request Process

1. Update `CHANGELOG.md` if your changes are user-visible
2. Ensure all CI jobs pass (SwiftLint, SwiftFormat, tests, DocC build)
3. Request review from maintainers
4. Address feedback and re-request review

## Questions?

For technical questions or discussion about the library:

- **Stack Overflow**: Use the `cdoauth1kit` tag
- **GitHub Discussions**: Open a discussion thread (if enabled)
- **Issues**: Use issues only for bugs and feature requests

## License

By contributing to CDOAuth1Kit, you agree that your contributions will be licensed under the same MIT license as the project.

Thank you for contributing!
