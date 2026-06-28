# Contributing to PackMatrix

Thank you for your interest in PackMatrix. This project is currently in active development and may be prepared for public open-source collaboration in the future.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Development Setup](#development-setup)
- [Branching](#branching)
- [Commit Guidelines](#commit-guidelines)
- [Pull Requests](#pull-requests)
- [Testing](#testing)
- [Style Guidelines](#style-guidelines)
- [Issue Reports](#issue-reports)

## Code of Conduct

Be respectful, constructive, and practical. Keep discussions focused on improving the app and the user experience.

## Development Setup

Requirements:

- Xcode 15 or later recommended
- iOS 17.0 or later simulator
- macOS 14.0 or later for Mac builds

Clone and open the project:

```bash
git clone https://github.com/your-username/PackMatrix.git
cd PackMatrix
open PackMatrix.xcodeproj
```

## Branching

Use short, descriptive branch names:

```text
feature/checklist-export
fix/trip-date-validation
docs/readme-updates
```

## Commit Guidelines

Prefer focused commits that explain the reason for the change.

Examples:

```text
Add trip checklist progress summary
Fix duplicate item prevention in quick add
Document SwiftData model relationships
```

## Pull Requests

Before opening a pull request:

1. Confirm the app builds for iOS.
2. Confirm the app builds for macOS when touching shared code.
3. Keep changes scoped to the stated issue.
4. Include screenshots for UI changes when possible.
5. Update documentation when behavior changes.

## Testing

Manual checks currently matter because the project does not yet include a full automated test suite.

Recommended checks:

- Create a master packing item
- Quick-add multiple items
- Create a trip
- Verify checklist generation
- Check and uncheck items
- Delete and restore trips where applicable
- Reopen the app and confirm SwiftData persistence

Command-line build checks:

```bash
xcodebuild \
  -project PackMatrix.xcodeproj \
  -scheme PackMatrix \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```bash
xcodebuild \
  -project PackMatrix.xcodeproj \
  -scheme PackMatrix \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Style Guidelines

- Prefer simple SwiftUI views and native controls.
- Keep model changes deliberate and documented.
- Avoid adding networking, authentication, Firebase, or backend dependencies unless the roadmap explicitly changes.
- Keep local-first behavior intact.
- Use SwiftData relationships consistently.
- Keep user-facing text clear and concise.

## Issue Reports

When reporting an issue, include:

- Device or simulator
- iOS or macOS version
- Xcode version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots or console output when useful
