# Package Creation Design

## Overview
This document describes the design for package creation functionality in FPDev.

## Feature Specification

### Command
```
fpdev package create <name> <path>

Options:
  --description TEXT   Package description
  --author TEXT        Package author
  --license TEXT        Package license (default: MIT)
  --version TEXT       Package version (default: 1.0.0)
  --homepage URL       Package homepage
  --repository URL      Git repository URL
  --files PATTERN       Files to include (glob pattern, default: *)
  --output PATH       Output directory (default: current directory)
```

### Package Structure

```
my-package/
├── .fpdev-package.json    # Package metadata
├── src/                   # Pascal source files
├── examples/               # Example code
├── docs/                   # Documentation
└── README.md               # Package README
```

### .fpdev-package.json Schema

```json
{
  "name": "package-name",
  "version": "1.0.0",
  "description": "Package description",
  "author": "Author Name",
  "license": "MIT",
  "homepage": "https://example.com",
  "repository": "https://github.com/user/repo",
  "dependencies": [
    {
      "name": "dependency-name",
      "version": ">=1.0.0"
    }
  ],
  "files": [
    "src/*",
    "examples/*",
    "docs/*",
    "README.md"
  ],
  "keywords": [
    "network",
    "http",
    "tcp"
  ]
}
```

## Implementation Plan

### Phase 2.1: Package Creation (Week 1)
- [ ] Create TPackageCreator class
- [ ] Implement CreatePackage method
- [ ] Auto-generate .fpdev-package.json
- [ ] Collect package files based on glob pattern
- [ ] Validate package structure

### Phase 2.2: Package Archive (Week 2)
- [ ] Create ZIP archive of package
- [ ] Include metadata and all specified files
- [ ] Verify archive integrity
- [ ] Output archive information

### Phase 2.3: Validation (Week 2)
- [ ] Validate package name format
- [ ] Validate version format (semantic versioning)
- [ ] Check required files exist
- [ ] Validate dependencies are available

## Testing Strategy

### Unit Tests
- Test package metadata generation
- Test file collection with glob patterns
- Test archive creation
- Test validation logic

### Integration Tests
- Test full package creation workflow
- Test package install from created archive
- Test dependency resolution with created package

## Error Handling

### Common Errors
- Missing source directory
- Invalid package name
- Invalid version format
- Missing required files
- Circular dependencies in metadata

### Error Messages
```
Error: Source directory not found: /path/to/package
Error: Invalid package name: my-package (must match [a-z0-9-]+)
Error: Invalid version format: 1.0 (expected X.Y.Z)
Error: No source files found matching pattern: src/*.pas
Error: Circular dependency detected: pkgA -> pkgB -> pkgA
```

## Usage Examples

### Basic Package Creation
```bash
# Create package from current directory
fpdev package create mypackage ./src

# Output: mypackage-1.0.0.zip
```

### With Options
```bash
# Create package with metadata
fpdev package create mypackage ./src \
  --description "My awesome package" \
  --author "John Doe" \
  --license "MIT" \
  --version "1.2.0"

# Create package with custom files
fpdev package create mypackage ./src \
  --files "src/*.pas,examples/*,docs/*" \
  --output ./packages
```

## Future Enhancements

### Package Signing
- Add digital signature support
- Verify package integrity
- Support for package signing keys

### Package Templates
- Create package from template
- Template library for common package types
- Custom template creation

### Interactive Mode
- Interactive package creation wizard
- Prompt for metadata fields
- Preview package structure before creation
