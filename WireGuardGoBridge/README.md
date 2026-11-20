# WireGuardGoBridge

This folder builds `libwg-go.a`, the Go half of WireGuard that WireGuardKit links against. Xcode runs `make` here through the `WireGuardGoBridgeiOS` and `WireGuardGoBridgemacOS` targets before it builds the tunnel extension.

It's a copy of `Sources/WireGuardKitGo` from [wireguard-apple](https://github.com/WireGuard/wireguard-apple) at tag `1.0.16-27`, with one change: `go.mod` points at a newer wireguard-go and `golang.org/x` packages, so it builds with current Go releases. The upstream copy pins 2023 versions that newer Go toolchains reject.

The files are MIT licensed, copyright Jason A. Donenfeld, as noted in their headers.

To bump wireguard-go later:

```sh
go get golang.zx2c4.com/wireguard@latest
go mod tidy
```
