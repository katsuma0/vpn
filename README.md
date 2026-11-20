# Hop

A one-button VPN for your iPhone and your Mac. Pick a country, tap the big button, and you're browsing from somewhere else.

<img src="App/Assets.xcassets/AppIcon.appiconset/icon-ios-1024.png" width="96" alt="Hop icon">

## Read this first

Two things nobody tells you about "free VPN" apps:

1. **The app is only half a VPN.** The other half is a server in the country you want to show up in, and servers cost money. Hop doesn't run any (that's how free VPNs end up selling your data). Instead it connects to any standard WireGuard server you give it. The easiest free source is Proton VPN's free plan, which covers a handful of big countries like the US, the Netherlands and Japan. You can also use a paid provider or your own server.
2. **Apple charges for VPN apps you build yourself.** Running a VPN app on your own devices needs a paid Apple Developer account ($99 a year). That's Apple's rule for the Network Extension permission, and a free Apple ID can't get around it. If you'd rather not pay, the official WireGuard app on the App Store takes the same config files.

## What you get

- One big button. Gray means off, orange means working on it, green means you're covered.
- A country list built from your servers, plus every major country you haven't added yet.
- Switch countries while connected and Hop hops straight over.
- A shield in the Mac menu bar so you never have to open the window.
- Import `.conf` files (several at once) or paste a config. Hop guesses the country from the file name, and you can fix it if it's wrong.
- No accounts, no tracking. Your configs stay on your device.

## Set it up (once)

1. Install Xcode 16 or newer, then Go: `brew install go`
2. Open `Config.xcconfig` and put your Team ID after `DEVELOPMENT_TEAM =`. Change `BUNDLE_ID_PREFIX` if `com.katsuma0` is taken.
3. Open `Hop.xcodeproj`. Everything WireGuard needs is already in the repo, so there's nothing to download.
4. **Mac:** pick the `Hop-macOS` scheme and press Run.
   **iPhone:** plug it in, turn on Developer Mode (Settings > Privacy & Security), pick the `Hop-iOS` scheme and your phone, then press Run. The simulator can't run VPN tunnels, so you need the real thing.
5. The first time you tap Connect, your device asks to add a VPN configuration. Say Allow.

## Get a free server

1. Make a free account at protonvpn.com.
2. Sign in on the website, open **Downloads**, and pick **WireGuard configuration**.
3. Choose a free server in the country you want and download the `.conf` file. Grab one per country.
4. In Hop, tap **Add Server** and pick the files. AirDrop them to your iPhone or save them to Files first.

Heads up: Proton's free plan allows one device at a time, so disconnect your Mac before connecting your phone.

## Run the tests

The tests cover the config parser, country detection and saving servers. They don't need signing or Go.

```sh
xcodebuild test -project Hop.xcodeproj -scheme HopTests -destination 'platform=macOS'
```

## How it fits together

```
SwiftUI app  ->  NETunnelProviderManager  ->  HopTunnel extension  ->  WireGuardKit     ->  wireguard-go
(App/)           (system VPN settings)       (Tunnel/)                (WireGuardKit/)      (WireGuardKit/Go/)
```

| Folder | What's in it |
| --- | --- |
| `App/` | The SwiftUI app for both platforms. `macOS/` holds the menu bar bits. |
| `Shared/` | Plain Swift used everywhere: config parser, countries, saved servers. |
| `Tunnel/` | The packet tunnel extension that runs WireGuard. |
| `Tests/` | Unit tests for `Shared/`. |
| `WireGuardKit/` | WireGuard's Apple library and Go engine, vendored so it builds on current Xcode. See its README. |
| `scripts/generate_project.rb` | Rebuilds `Hop.xcodeproj` if you add or move files. |

## When something breaks

- **Build fails in a WireGuardGoBridge target:** Go isn't installed or isn't on the path Xcode sees. `brew install go` fixes it. The Makefile already looks in `/opt/homebrew/bin` and `/usr/local/bin`.
- **"Signing requires a development team":** fill in `DEVELOPMENT_TEAM` in `Config.xcconfig`.
- **"Provisioning profile doesn't include the Network Extensions capability":** your Apple account isn't a paid developer account yet.
- **Connected but pages won't load:** the server's probably down or the config is stale. Download a fresh one, or try another country.
