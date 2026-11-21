# Getting Corpus onto an iPhone (TestFlight)

iOS apps can only be built on a Mac. Corpus is developed on Windows, so GitHub Actions does the building:

- **Every push** — `ci.yml` compiles the iOS app unsigned, to prove it builds.
- **On demand** — `testflight.yml` builds a signed app and uploads it to TestFlight, where you install it on your iPhone with Apple's TestFlight app.

The TestFlight workflow needs a one-time setup in your Apple Developer account ($99/year) and seven secrets in the GitHub repo.

> Status: the workflow is written but has **not been run yet** — it cannot be until the secrets below exist. Expect to fix a detail or two on the first run.

## 1. Apple setup (once)

All of this is done in a browser except step 3, which needs a tool to make a certificate request (see the note there).

1. **App ID** — [Certificates, Identifiers & Profiles › Identifiers](https://developer.apple.com/account/resources/identifiers/list) › **+** › App IDs › App.
   - Bundle ID: `app.corpus.corpus` (explicit). If it is taken, pick another and set it as the `IOS_BUNDLE_ID` repo *variable* (step 2).
   - Tick the **HealthKit** capability.
2. **App record** — [App Store Connect › Apps](https://appstoreconnect.apple.com/apps) › **+** › New App. Platform iOS, name "Corpus" (or any free name), the bundle ID from above, any SKU.
3. **Distribution certificate** — Certificates › **+** › *Apple Distribution*. Apple asks for a certificate signing request (CSR). Without a Mac, create one with OpenSSL (it ships with Git for Windows):
   ```sh
   openssl genrsa -out dist.key 2048
   openssl req -new -key dist.key -out dist.csr -subj "/CN=Corpus Distribution"
   ```
   Upload `dist.csr`, download `distribution.cer`, then bundle key and certificate into a password-protected `.p12`:
   ```sh
   openssl x509 -inform DER -in distribution.cer -out dist.pem
   openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out dist.p12
   ```
   Keep `dist.key` and `dist.p12` somewhere safe and **out of the repo**.
4. **Provisioning profile** — Profiles › **+** › *App Store Connect* (under Distribution). Choose the App ID and the certificate, name it e.g. `Corpus App Store`, download the `.mobileprovision` file.
5. **API key** (lets CI upload) — [App Store Connect › Users and Access › Integrations › App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) › **+**, role *App Manager*. Note the **Key ID** and **Issuer ID** and download the `.p8` file (one chance only).

## 2. GitHub secrets

Repo › Settings › Secrets and variables › Actions › **New repository secret**. Files are stored base64-encoded; in Git Bash: `base64 -w0 dist.p12 | clip`.

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Your 10-character Team ID ([Membership details](https://developer.apple.com/account#MembershipDetailsCard)) |
| `IOS_DIST_CERT_P12` | base64 of `dist.p12` |
| `IOS_DIST_CERT_PASSWORD` | The password you gave the `.p12` |
| `IOS_PROVISIONING_PROFILE` | base64 of the `.mobileprovision` file |
| `IOS_PROFILE_NAME` | The profile's name, e.g. `Corpus App Store` |
| `APP_STORE_CONNECT_KEY_ID` | Key ID from step 5 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from step 5 |
| `APP_STORE_CONNECT_API_KEY` | base64 of the `.p8` file |

Optional *variable* (Variables tab): `IOS_BUNDLE_ID`, if you could not use `app.corpus.corpus`.

## 3. Ship a build

Actions › **TestFlight** › *Run workflow* (or push a tag such as `v0.1.0`). After 15–30 minutes the build appears in App Store Connect › TestFlight. Add yourself as an internal tester, then install it from the TestFlight app on your iPhone.

The build number is the workflow run number, so every run is accepted as a new build. The version (`1.0.0`) comes from `pubspec.yaml`.

## Renewal

The certificate and profile expire after a year. Repeat steps 3–4 and update the three matching secrets.
