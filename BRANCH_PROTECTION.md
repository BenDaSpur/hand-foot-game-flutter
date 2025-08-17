# Branch Protection Setup

To ensure code quality and prevent direct pushes to main branches, set up branch protection rules.

## Automated Setup

The repository includes a GitHub Action (`.github/workflows/setup-branch-protection.yml`) that automatically configures branch protection when code is pushed to main/master branches.

## Manual Setup (Repository Admin)

If automatic setup fails, manually configure branch protection:

### Steps:
1. Go to **Settings** → **Branches** in your GitHub repository
2. Click **Add branch protection rule**
3. Configure the following settings:

#### Branch name pattern:
```
main
```

#### Protection Rules:
- ✅ **Require a pull request before merging**
  - Required approving reviews: `1`
  - ✅ Dismiss stale PR approvals when new commits are pushed
  - ❌ Require review from code owners (optional)

- ✅ **Require status checks to pass before merging**
  - ✅ Require branches to be up to date before merging
  - Required status checks:
    - `test-and-analyze`
    - `build-test`

- ❌ **Require conversation resolution before merging** (optional)
- ❌ **Require signed commits** (optional)
- ❌ **Require linear history** (optional)
- ❌ **Require deployments to succeed before merging** (not applicable)

#### Restrictions:
- ❌ **Restrict pushes that create matching branches** (allow anyone)

#### Rules applied to everyone:
- ❌ **Allow force pushes** (disabled for security)
- ❌ **Allow deletions** (disabled for security)

### Result:
Once configured, all changes to the main branch must:
1. Go through a Pull Request
2. Pass all CI checks (tests, formatting, analysis, build)
3. Get at least 1 approving review
4. Have all CI status checks green

## CI Status Checks

The following checks must pass:

### `test-and-analyze`
- Code formatting verification
- All 74 tests passing
- Static analysis (flutter analyze)

### `build-test`
- Successful debug build (APK)
- Dependency verification

## Troubleshooting

### If branch protection setup fails:
- Check repository permissions (admin access required)
- Manually configure using the steps above
- Ensure CI workflow names match the required status checks

### If CI checks fail:
- Run `./format_and_test.sh` locally to verify issues
- Check the Actions tab for detailed error logs
- Ensure all tests pass with `flutter test`
- Verify code analysis with `flutter analyze`