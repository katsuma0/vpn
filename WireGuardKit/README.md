# WireGuardKit (vendored)

WireGuard's Apple library, compiled straight into Hop's tunnel extension. It comes from [wireguard-apple](https://github.com/WireGuard/wireguard-apple) at tag `1.0.16-27`, MIT licensed (see `COPYING`).

Why it lives here instead of coming in as a Swift package: upstream's `Package.swift` declares tools version 5.3 but uses platform versions that need 5.5, and current Xcode refuses to load it. Compiling the sources directly is also how WireGuard's own app builds.

| Folder | What's in it |
| --- | --- |
| `Swift/` | The Swift API: `WireGuardAdapter`, `TunnelConfiguration` and friends. Unchanged from upstream. |
| `C/` | Curve25519 key helpers. Unchanged from upstream. |
| `Go/` | The Go engine. Xcode's `WireGuardGoBridge` targets run `make` here to build `libwg-go.a`. `go.mod` points at a newer wireguard-go and `golang.org/x` packages so it builds with current Go. |

To bump wireguard-go later, run this in `Go/`:

```sh
go get golang.zx2c4.com/wireguard@latest
go mod tidy
```
