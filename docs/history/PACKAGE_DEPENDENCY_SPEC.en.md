# Package Dependency Metadata Specification

## Overview

This document defines the format for package dependency metadata in FPDev package management system.

## Metadata Format

### .fpdev-package.json Schema

```json
{
  "name": "string",
  "version": "string",
  "description": "string",
  "author": "string",
  "license": "string",
  "homepage": "string",
  "repository": "string",
  "dependencies": [
    {
      "name": "string",
      "version": "string",
      "optional": false
    }
  ],
  "devDependencies": [
    {
      "name": "string",
      "version": "string",
      "optional": false
    }
  ],
  "files": [
    "string"
  ],
  "keywords": [
    "string"
  ]
}
```

## Field Descriptions

### Core Fields

- `name` (string, required): Package identifier (e.g., "synapse", "fpjson")
- `version` (string, required): Semantic version (e.g., "1.2.0", "1.2.0-beta")
- `description` (string, optional): Brief package description
- `author` (string, optional): Package author name
- `license` (string, optional): License type (e.g., "MIT", "LGPL-2.1")
- `homepage` (string, optional): Package website URL
- `repository` (string, optional): Git repository URL

### Dependencies

- `dependencies` (array, optional): Runtime dependencies
  - `name` (string, required): Dependency package name
  - `version` (string, required): Version constraint (e.g., ">=1.0.0", "^1.2.0", "1.2.0")
  - `optional` (boolean, optional, default: false): Whether dependency is optional

- `devDependencies` (array, optional): Development-time dependencies (e.g., testing frameworks)

### Files

- `files` (array, optional): List of files/directories to include in package

### Keywords

- `keywords` (array, optional): Search keywords for package discovery

## Version Constraints

### Supported Operators

- `>=` : Greater than or equal to (e.g., ">=1.0.0")
- `>`  : Greater than (e.g., ">1.0.0")
- `<=` : Less than or equal to (e.g., "<=2.0.0")
- `<`  : Less than (e.g., "<2.0.0")
- `~`  : Tilde range (patch updates only, e.g., "~1.2.3" = ">=1.2.3 <1.3.0")
- `^`  : Caret range (minor updates only, e.g., "^1.2.3" = ">=1.2.3 <2.0.0")
- `*`  : Any version
- Empty: Exact version match

### Examples

```json
{
  "dependencies": [
    {
      "name": "fpjson",
      "version": "^1.0.0"
    },
    {
      "name": "openssl",
      "version": ">=1.1.0"
    },
    {
      "name": "lazlogger",
      "version": "1.2.0"
    },
    {
      "name": "testing-framework",
      "version": ">=2.0.0",
      "optional": true
    }
  ]
}
```

## Dependency Resolution Strategy

### Conflict Resolution

1. **Strict Version Mode** (default): Only exact version matches allowed
2. **Semantic Version Mode**: Allow updates within semver constraints
3. **Minimum Version Mode**: Use minimum version that satisfies all constraints

### Cycle Detection

- Detect circular dependencies during graph traversal
- Report error with dependency chain
- Prevent installation if cycle detected

### Installation Order

Dependencies are installed in topological order:
1. Leaves (no dependencies) -> first
2. Intermediate packages -> middle
3. Root package -> last

### Example Dependency Graph

```
     myapp (root)
        |
    +---+---+
    |   |   |
  libA libB libC
    |   |
    +---+
    |
  libD (leaf)
```

Installation order: libD, libA, libC, libB, myapp

## Error Handling

### Common Errors

1. **Missing Dependency**: Required package not found in any repository
2. **Version Conflict**: No version satisfies all constraints
3. **Circular Dependency**: A -> B -> C -> A
4. **Self Dependency**: Package depends on itself

### Error Messages

```
Error: Missing dependency 'openssl' required by 'synapse'
Error: Version conflict for 'fpjson': requires '>=1.2.0' but '1.1.0' is installed
Error: Circular dependency detected: libA -> libB -> libC -> libA
```

## Example Package Metadata

### Complete Example

```json
{
  "name": "synapse",
  "version": "1.2.0",
  "description": "Internet communication library for Free Pascal",
  "author": "Lukas Gebauer",
  "license": "MPL-2.0",
  "homepage": "https://github.com/synapse/synapse",
  "repository": "https://github.com/synapse/synapse.git",
  "dependencies": [
    {
      "name": "fpjson",
      "version": "^1.0.0"
    },
    {
      "name": "openssl",
      "version": ">=1.1.0"
    }
  ],
  "devDependencies": [
    {
      "name": "fpcunit",
      "version": ">=1.0.0"
    }
  ],
  "files": [
    "src/*",
    "examples/*",
    "LICENSE"
  ],
  "keywords": [
    "network",
    "http",
    "tcp",
    "ssl",
    "communication"
  ]
}
```

### Minimal Example

```json
{
  "name": "helloworld",
  "version": "1.0.0",
  "description": "Simple hello world package",
  "files": [
    "*"
  ]
}
```

## Backward Compatibility

- For packages without .fpdev-package.json: Use simplified metadata parsing
- Fallback to index.json repository metadata
- Maintain compatibility with existing package format

## Migration Path

1. Phase 1: Support both .fpdev-package.json and index.json
2. Phase 2: Recommend .fpdev-package.json for new packages
3. Phase 3: Require .fpdev-package.json (future version)
