# Google Play release checklist

## Signing

1. Create an upload keystore and keep it outside source control.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Replace the placeholder values with the real keystore values.
4. Build with `flutter build appbundle --release`.
5. Verify the AAB is signed with the upload key before uploading it.

Without `android/key.properties`, local release builds use the debug key and are not suitable for Google Play.

## Store requirements

- Confirm the application ID is unique and final.
- Increase `version` in `pubspec.yaml` for each upload.
- Prepare an accurate privacy policy and Data Safety declaration.
- Explain VPN, usage access, package visibility, notification, and foreground-service permissions.
- Confirm the app qualifies for Google Play VPN and `QUERY_ALL_PACKAGES` policies.
- Add store icon, screenshots, description, category, content rating, and support contact.
- Test the signed AAB through an internal or closed Play test before production.
