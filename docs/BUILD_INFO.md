# Build Info

Specific build information about various platforms.

## Windows build

The Windows build doesn't use preview_mt as the implementation is not complete, so the process crashes. This is accurate as of Crystal 1.9.0. Therefore, the Windows build has only concurrency, but not parallelism support. In practice, it maximises a single (physical) CPU core which reduces it performance even compared to running the Linux binary under WSL2. Also, Microsoft Defender Real-time protection needs to be turned off, otherwise most of the CPU time is spent analysing the download ranges, which further limits the performance. All in, with AV off, it adds up to 5 minutes to the download time, but your mileage may vary, particularly on the available CPU and networking.

Checking with `--check` is orders of magniture slower than the Linux build. We're talking minutes compared to under 2 seconds under WSL2.

The Windows build is built with:

```
crystal.exe build --release --static .\pwned-password-downloader.cr
```

## macOS build

The macOS build is a bit more challenging for a few reasons:

 * macOS doesn't support fully static builds.
 * Depending on openssl installed via brew is poor binary distribution experience (so this needs to be statically built).
 * Some degree of cross-compilation needs to be implemented to create universal (fat) binaries to support both x86_64 and arm64.

This setup is somewhat easier on ARM Macs due to Rosetta 2, so setting up two brew installations, each with their native prefix is supported.

On an Intel Mac, to cross-compile for arm64 there needs to be a second brew installation by:

```bash
sudo mkdir /opt/armbrew
sudo chown $UID:$GID /opt/armbrew
cd /opt && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C armbrew
/opt/armbrew/bin/brew install --force-bottle $(/opt/armbrew/bin/brew --cache --bottle-tag=arm64_big_sur openssl)
```

This makes the desired libraries available at `/opt/armbrew/lib`.

This setup is supported by the `downloader-macos` make target. It produces the expected outcome:

```bash
file pwned-password-downloader-darwin-universal
pwned-password-downloader-darwin-universal: Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64]
pwned-password-downloader-darwin-universal (for architecture x86_64):	Mach-O 64-bit executable x86_64
pwned-password-downloader-darwin-universal (for architecture arm64):	Mach-O 64-bit executable arm64

otool -L pwned-password-downloader-darwin-universal
pwned-password-downloader-darwin-universal:
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.11)
	/usr/lib/libpcre.0.dylib (compatibility version 1.0.0, current version 1.1.0)
	/usr/lib/libiconv.2.dylib (compatibility version 7.0.0, current version 7.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.0.0)
```
