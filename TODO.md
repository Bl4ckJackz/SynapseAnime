# TODO: Resolve All Problems in the App

## Backend Build Errors Fixes
- [ ] Fix import in backend/src/anime/stream.controller.ts: change '../sources/local-file.source' to '../sources/local-file.source.js'
- [ ] Fix Response type in backend/src/anime/stream.controller.ts: change res: any to res: Response
- [ ] Fix JWT strategy options in backend/src/auth/jwt.strategy.ts: add passReqToCallback: false
- [ ] Fix validateUser call in backend/src/auth/jwt.strategy.ts: change to findUserById
- [ ] Fix relations in backend/src/entities/user.entity.ts: add NotificationSettings import, change @OneToOne to callback, change fcmToken type to string | null
- [ ] Fix relation in backend/src/entities/notification-settings.entity.ts: change @OneToOne to callback

## Mobile App Issues (To be checked after backend fixes)
- [ ] Check for any compilation or runtime issues in mobile Flutter app
- [ ] Verify API integrations and data flow
- [ ] Test UI components and navigation

## Testing
- [ ] Run backend build to verify all errors are resolved
- [ ] Run mobile build and test app functionality
