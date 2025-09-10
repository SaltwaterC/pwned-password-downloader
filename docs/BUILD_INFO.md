# Build Info

Specific build information about various platforms.

## Linux build

This should be the most stable of all. It also has the best performance.

The static build loses some performance. This seems to be related to the use of musl rather than glibc. This has been made to be easily redistributable.

This is how check behaves against a downloaded list with a couple of files deliberately altered (one empty, one missing):

```bash
./pwned-password-downloader-linux-amd64 -d ~/.pwn -c # static release build
ERROR: ~/.pwn/E00B2.txt is empty
ERROR: ~/.pwn/F00A1.txt is missing
Total successful checks: 1048574
./pwned-password-downloader-linux-amd64 -d ~/.pwn -c  0.35s user 1.14s system 56% cpu 2.632 total

time ./dynamic -d ~/.pwn -c # dynamically linked against glibc et al, built with --release
ERROR: ~/.pwn/E00B2.txt is empty
ERROR: ~/.pwn/F00A1.txt is missing
Total successful checks: 1048574
./dynamic -d ~/.pwn -c  0.17s user 1.13s system 108% cpu 1.190 total
```

## Windows build

The Windows build doesn't use preview_mt as the implementation is not complete, so the process crashes. This is accurate as of Crystal 1.9.0. Therefore, the Windows build has only concurrency, but not parallelism support. In practice, it maximises a single (physical) CPU core which reduces it performance even compared to running the Linux binary under WSL2. Also, Microsoft Defender Real-time protection needs to be turned off, otherwise most of the CPU time is spent analysing the download ranges, which further limits the performance. All in, with AV off, it adds up to 5 minutes to the download time, but your mileage may vary, particularly on the available CPU and networking.

Checking with `--check` is orders of magniture slower than the Linux build. We're talking minutes compared to under 2 seconds under WSL2.

The Windows build is built with:

```
crystal.exe build --release --static .\src\pwned-password-downloader.cr
```

## macOS build

```bash
brew install crystal jq # crystal_version in Makefile must match this version
```

The macOS build is a bit more challenging for a few reasons:

 * macOS doesn't support fully static builds.
 * Depending on openssl installed via brew is poor binary distribution experience (so this needs to be statically built).
 * Some degree of cross-compilation needs to be implemented to create universal (fat) binaries to support both x86_64 and arm64.


This setup is supported by the `macos` make target. It produces the expected outcome:

```bash
file pwned-password-downloader-darwin-universal
pwned-password-downloader-darwin-universal: Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64]
pwned-password-downloader-darwin-universal (for architecture x86_64):	Mach-O 64-bit executable x86_64
pwned-password-downloader-darwin-universal (for architecture arm64):	Mach-O 64-bit executable arm64

# macOS 13
otool -L pwned-password-downloader-darwin-universal
pwned-password-downloader-darwin-universal:
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.11)
	/usr/lib/libiconv.2.dylib (compatibility version 7.0.0, current version 7.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1319.100.3)
```

Note: OpenSSL is statically linked. The OpenSSL binary builds are fetched from Homebrew bottled builds. This only works for supported macOS versions which at the time of writing this, the oldest is macOS 13.
