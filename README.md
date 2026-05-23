# Binary Coffee Mobile

Flutter app for reading and interacting with Binary Coffee articles on Android, macOS, Windows, and Linux.

The app follows the same public GraphQL API used by the Binary Coffee Edge extension:

- `https://api.binarycoffee.dev/graphql`
- Article list with `enable: true`, pagination, search, tags, author filter, stats, banners, avatars, and article detail.
- Authenticated actions for GitHub login, likes, comments, drafts, profile, user posts, stats, and subscription.

## Design

The UI adapts the Binary Coffee web identity to mobile and desktop:

- Primary palette from the site and extension: `#19C65E`, `#01CD6A`, light `#FAFFFE`, and dark `#111B21`.
- Fira Code font from the Binary Coffee frontend assets.
- App icons and imagery from `binary-coffee-dev/our-identity`.
- Native Material 3 widgets so each desktop/mobile target keeps a platform-friendly look and feel.

## GitHub Auth

GitHub authentication opens the same OAuth provider flow used by the Binary Coffee dashboard client. Paste the returned `code` into the app, and the app exchanges it with:

```graphql
mutation($provider: String!, $code: String!) {
  loginWithProvider(provider: $provider, code: $code)
}
```

The profile screen also accepts an existing JWT, which mirrors the extension's token-based session path.

## Local Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Builds

```bash
flutter build apk --release
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

Desktop builds must run on their native OS runners. The GitHub Actions workflows package:

- Android `.apk`
- macOS `.dmg`
- Windows `.zip` containing the `.exe`
- Linux `.deb`

Release artifacts are published when pushing a tag like `v1.0.0`.
