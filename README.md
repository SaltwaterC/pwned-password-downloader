# pwned-password-downloader

Cross-platform alternative to official [PwnedPasswordsDownloader](https://github.com/HaveIBeenPwned/PwnedPasswordsDownloader). While .NET Core runtime is available on more platforms these days, this allows the binaries to run without any particular runtime.

While it implements a parallelism option, it may not work exactly the same as the official `PwnedPasswordsDownloader`. This sets the number of fibers (coroutines) to run concurrently. The binary must be built with `preview_mt` to enable Crystal runtime's parallelism support and the default numbers of system theads (forks really) is set as 4, unless overriden via `CRYSTAL_WORKERS` environment variable. While fibers by themselves may get some benefit without threading while waiting for IO, it won't get the full performance benefit without an appropriate number of threads.

The responses from api.pwnedpasswors.com are gzip compressed and transparently decompressed by default by Crystal's HTTP library.

Supports additional features not available in the official downloader:

 * Saves range ETags to make it easier to verify whether a range file requires update.
 * Saves a single specified range in the output directory. Useful if a range fails to download.
 * Basic integrity checks i.e whether all files have been downloaded and their length is non-zero.
 * TODO: option to strip CRLF to keep LF only (UNIX line termination) - shaves off about 0.5 GiB of disk space
 * TODO: option to strip counters - shaves off about 1.1 GiB of disk space

Missing feature from official downloader: single file mode. The single file mode is difficult to work with due to sheer size so it is rather useless by itself without either splitting the file or indexing the file. Both options (splitting and indexing) are time consuming and by default (this tool) or as an option (official downloader) gets the ranges as separate files anyway which are easy to query. Considering that there's no single archive to speed up the download as any tool would still need to send 1048576 requests to api.pwnedpasswords.com to get the ranges, this feature is rather useless by itself.

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

## Usage

```bash
# print help
./pwned-password-downloader -h
Usage: pwned-password-downloader
    -h, --help                       Show this help
    -d, --output-directory pwnedpasswords
                                     Output directory. Defaults to pwnedpasswords
    -p, --parallelism 128            The number of parallel requests to make to Have I Been Pwned to download the hash ranges. If omitted or less than two, defaults to eight times the number of processors on the machine (128).
    -r, --range 5HEXCHARS            A single range to download in the output directory pwnedpasswords. Useful to recover when some ranges may fail the request.
    -c, --check                      Check whether all ranges have been downloaded and whether their file size is > 0
    -n, --no-etags                   Disable checking the ETags while downloading the ranges. Effectively, downloads everything from scratch. Does not update ETag list/save ETag file.

./pwned-password-downloader # 1st invoke - downloads everything in pwnedpasswords
# beef up number of worker threads
CRYSTAL_WORKERS=16 ./pwned-password-downloader # 2nd invoke - send requests with ETag values and updates changed ranges
./pwned-password-downloader -c # invoke checks
./pwned-password-downloader -n # ignores ETags and overwrites all files if found
./pwned-password-downloader -r 00000 # downloads single range
```
