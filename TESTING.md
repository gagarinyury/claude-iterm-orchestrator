# 🧪 Testing Guide

## Quick Commands

```bash
# 🚀 Run everything
npm run check              # Lint + Test

# 🧪 Testing
npm test                   # Run all tests once
npm run test:watch         # Watch mode (auto-rerun)
npm run test:ui            # Visual test UI
npm run test:coverage      # Coverage report

# 🔍 Linting
npm run lint               # Check code
npm run lint:fix           # Auto-fix issues
npm run format             # Format code
```

## Test Results

Current status:

```
✅ 7/7 tests passing (100%)
✅ Lint checks passed
✅ All 9 bash scripts present and executable
✅ Config files valid
```

## Test Categories

### 1. MCP Server Tests (2)
- ✅ Server initialization
- ✅ Tools listing

### 2. Script Validation (2)
- ✅ All bash scripts exist
- ✅ Scripts have execute permissions

### 3. Configuration Tests (3)
- ✅ package.json valid
- ✅ biome.json valid
- ✅ vitest.config.js exists

## Manual Testing

### Test Variables System

```bash
./test-variables-simple.sh
```

Expected output:
- Worker created with ID
- Variables set and retrieved
- Worker info shows variables
- Worker cleaned up

### Test MCP Server Integration

```bash
./test-variables-mcp.sh
```

Expected output:
- MCP server starts
- Worker created via MCP
- Variables set via MCP tools
- All operations logged

### Full Claude Integration Test

```bash
./test-full-claude-mcp.sh
```

Expected output:
- Claude worker created
- Claude CLI launched
- Question sent
- Answer received
- Worker remains open for inspection

## Debugging Tests

### Run single test file

```bash
npx vitest tests/server.test.js
```

### Run specific test

```bash
npx vitest tests/server.test.js -t "should start and respond"
```

### Verbose output

```bash
npx vitest --reporter=verbose
```

### Debug mode

```bash
node --inspect-brk ./node_modules/vitest/vitest.mjs
```

## Coverage Analysis

Generate coverage:

```bash
npm run test:coverage
```

View HTML report:

```bash
open coverage/index.html
```

Expected coverage:
- Lines: Focus on MCP handlers
- Branches: Tool registration paths
- Functions: All exported functions
- Statements: Main execution paths

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm run check
```

### GitLab CI Example

```yaml
test:
  image: node:18
  script:
    - npm install
    - npm run check
  only:
    - main
    - merge_requests
```

## Writing New Tests

### Example test structure

```javascript
import { describe, it, expect } from "vitest";

describe("New Feature", () => {
  it("should do something", () => {
    // Arrange
    const input = "test";

    // Act
    const result = processInput(input);

    // Assert
    expect(result).toBe("expected");
  });
});
```

### Testing async operations

```javascript
it("should handle async operation", async () => {
  const result = await asyncFunction();
  expect(result).toBeDefined();
});
```

### Testing with timeout

```javascript
it("should complete within time", async () => {
  // Test logic
}, 5000); // 5 second timeout
```

## Troubleshooting

### Tests fail with "MODULE_NOT_FOUND"

Check that `server.js` exists in project root:
```bash
ls -la server.js
```

### Tests timeout

Increase timeout in test file:
```javascript
it("slow test", async () => {
  // ...
}, 10000); // 10 seconds
```

### Lint errors

Auto-fix most issues:
```bash
npm run lint:fix
```

For unsafe fixes:
```bash
npx biome check --write --unsafe .
```

### Coverage not generated

Install coverage provider:
```bash
npm install -D @vitest/coverage-v8
```

## Best Practices

1. **Run tests before commit**
   ```bash
   npm run check
   ```

2. **Keep tests fast** - Current suite runs in ~200ms

3. **Test behavior, not implementation** - Focus on what, not how

4. **Use descriptive test names** - "should do X when Y"

5. **Clean up resources** - Use `afterEach` for cleanup

6. **Mock external dependencies** - Don't make real API calls

7. **Test edge cases** - Empty inputs, nulls, errors

## Performance Benchmarks

| Operation | Time |
|-----------|------|
| Full test suite | ~200ms |
| Lint check | ~5ms |
| Format check | ~4ms |
| Complete check | ~300ms |

Target: Keep under 500ms for fast feedback loop.

---

**Need help?** Check the [main README](README.md) or open an issue.
