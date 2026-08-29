# AssembleAI GitHub Actions CI/CD Pipeline

This repository contains an automated GitHub Actions CI workflow in [`.github/workflows/ios_build.yml`](file:///f:/devlopment/iosproject/AssembleAI/.github/workflows/ios_build.yml).

---

## How It Works

1. **Automated macOS Runner**: Every `git push` or `pull_request` triggers a build job on a cloud-hosted macOS runner (`macos-14`, Apple Silicon M1/M2).
2. **iOS Target Compilation**: Executes `xcodebuild build` for the AssembleAI target using iOS 17 SDK.
3. **Unit Test Verification**: Executes `xcodebuild test` on the iPhone 15 Pro simulator target to run unit tests in `AssembleAITests`.

---

## How to View Build Results

1. Go to your repository on GitHub: `https://github.com/anand-mukul/AssembleAI`
2. Click the **Actions** tab at the top.
3. Select the latest workflow run to see live build logs, compiler status, and test output.
