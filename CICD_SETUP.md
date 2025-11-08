# CI/CD Setup Instructions

## GitHub Actions Workflow

The `.github/workflows/android.yml` file contains the automated build pipeline for this project.

### Manual Setup Required

Due to GitHub token scope limitations, the workflow file needs to be added manually to enable CI/CD:

```bash
# Option 1: Add via GitHub web interface
# 1. Go to https://github.com/Dezirae-Stark/QuantumTrader-Pro
# 2. Navigate to .github/workflows/
# 3. Click "Add file" > "Create new file"
# 4. Name it "android.yml"
# 5. Copy contents from local .github/workflows/android.yml
# 6. Commit directly to main branch

# Option 2: Use gh CLI with proper token
gh auth refresh -s workflow
git add .github/workflows/android.yml
git commit -S -m "ci: Add GitHub Actions workflow for APK builds"
git push origin main
```

### What the CI/CD Pipeline Does

1. **Automated APK Build**: Compiles the Flutter app to APK on every push to main
2. **Code Analysis**: Runs Flutter analyze for code quality
3. **Testing**: Executes unit tests (if present)
4. **Artifact Upload**: Stores the built APK for download
5. **Release Creation**: Automatically creates/updates a GitHub release with the latest APK

### Accessing Built APK

Once the workflow is enabled:

- Go to **Actions** tab in the repository
- Click on the latest successful workflow run
- Download the **QuantumTraderPro-APK** artifact
- Or download from the **Releases** page (tagged as "latest")

### Build Status Badge

Add this to your README to show build status:

```markdown
![Build Status](https://github.com/Dezirae-Stark/QuantumTrader-Pro/actions/workflows/android.yml/badge.svg)
```

---

## Local Build

To build the APK locally without CI/CD:

```bash
# Ensure Flutter is installed
flutter doctor

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

---

**Note**: The workflow file is included in this repository but requires manual activation due to OAuth token workflow scope restrictions.
