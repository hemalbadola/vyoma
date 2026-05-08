# Dependency Notes

## Pinned packages

- `flutter_local_notifications: ^19.5.0`
- `google_sign_in: ^6.3.0`
- `permission_handler: ^11.4.0`
- `google_fonts: ^6.3.3`
- `googleapis: ^15.0.0`
- `googleapis_auth: ^2.0.0`

These are pinned to avoid accidental major API surface changes during feature work and keep CI/build behavior stable across branch merges.

## Manual migration required before major upgrade

- `flutter_local_notifications`:
  major upgrades include plugin API/platform behavior changes and permission handling differences; migration test needed per platform.
- `google_sign_in`:
  major upgrades include revised auth flows/scopes/platform SDK requirements; migration test needed for Android, iOS, web.

## Upgrade window target

- Target major upgrade review after each feature branch merge.
- Run migration branch per package and validate with `flutter analyze` + smoke auth/notification flows before landing.
