# IPification iOS SDK

Public source repository for the IPification iOS SDK.

## Overview

The SDK provides IPification authentication flows for iOS apps, including:

- IP authentication
- Coverage checks
- Instant Messaging (IM) authentication UI helpers
- SMS fallback / SMS OTP verification

## Requirements

- iOS 12.0+
- Xcode 15 or newer recommended
- Swift 5

## Project Layout

```text
IPificationSDK/IPificationSDK/
├── Common/        Shared configuration, errors, logging, and base response types
├── IP/            IP authentication, coverage, networking, request/response protocols
├── IM/            Instant Messaging UI and IM-specific helpers
├── SMS/           SMS authentication and OTP verification
└── Utils/         Shared utilities
```

## Build

```bash
xcodebuild \
  -project IPificationSDK/IPificationSDK.xcodeproj \
  -scheme IPificationSDK \
  -configuration Release \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Usage Documentation

See the documentation under `docs/ios` and `docs/ios-automode`.

## Contributing

Please open changes through pull requests. Keep `main` stable and avoid committing generated artifacts such as `build`, `DerivedData`, `.xcframework`, or `.zip` files.
