# pwned-password-downloader

Cross-platform alternative to official [PwnedPasswordsDownloader](https://github.com/HaveIBeenPwned/PwnedPasswordsDownloader). While .NET Core runtime is available on more platforms these days, this allows the binaries to run without any particular runtime.

While it implements a parallelism option, it may not work exactly the same as the official `PwnedPasswordsDownloader`. This sets the number of fibers (coroutines) to run concurrently. The binary must be built with `preview_mt` to enable Crystal runtime's parallelism support and the default numbers of system theads (forks really) is set as 4, unless overriden via `CRYSTAL_WORKERS` environment variable. While fibers by themselves may get some benefit without threading while waiting for IO, it won't get the full performance benefit without an appropriate number of threads.

The responses from api.pwnedpasswors.com are gzip compressed and transparently decompressed by default by Crystal's HTTP library.

Supports additional features not available in the official downloader:

 * Saves range ETags to make it easier to verify whether a range file requires update.
 * Saves a single specified range in the output directory. Useful if a range fails to download.
 * Basic integrity checks i.e whether all files have been downloaded and their length is non-zero.
 * Option to strip CRLF to keep LF only (UNIX line termination) - shaves off disk space
 * Option to strip counters - shaves off a measurable chunk of disk space plus the space saving of lacking CR

Missing feature from official downloader: single file mode. The single file mode is difficult to work with due to sheer size so it is rather useless by itself without either splitting the file or indexing the file. Both options (splitting and indexing) are time consuming and by default (this tool) or as an option (official downloader) gets the ranges as separate files anyway which are easy to query. Considering that there's no single archive to speed up the download as any tool would still need to send 1048576 requests to api.pwnedpasswords.com to get the ranges, this feature is rather useless by itself.

The additional details about specific platforms build information is detailed in [Build Info](docs/BUILD_INFO.md).

## Usage

```bash
# print help
./pwned-password-downloader -h
Usage: pwned-password-downloader
    -h, --help                       Show this help
    -v, --version                    Print version number
    -d, --output-directory pwnedpasswords
                                     Output directory. Defaults to pwnedpasswords
    -p, --parallelism 64             The number of parallel requests to make to Have I Been Pwned to download the hash ranges. Defaults to eight times the number of processors on the machine (64).
    -r, --range 5HEXCHARS            A single range to download in the output directory pwnedpasswords. Useful to recover when some ranges may fail the request.
    -c, --check                      Check whether all ranges have been downloaded and whether their file size is > 0
    -n, --no-etags                   Disable checking the ETags while downloading the ranges. Effectively, downloads everything from scratch. Does not update ETag list/save ETag file.
    -t, --type sha1                  Specify the hash type to download. One of: sha1, ntlm
    -s, --strip                      Specify what data to strip. One of: cr, count. Note: count also strips CR

./pwned-password-downloader # 1st invoke - downloads everything in pwnedpasswords
# beef up number of worker threads
CRYSTAL_WORKERS=16 ./pwned-password-downloader # 2nd invoke - send requests with ETag values and updates changed ranges
./pwned-password-downloader -c # invoke checks
./pwned-password-downloader -n # ignores ETags and overwrites all files if found
./pwned-password-downloader -r 00000 # downloads single range
```

Note: to avoid naming conflicts, the NTLM hashes use `${RANGE}.ntlm.txt` file names rather than `${RANGE}.txt` in the target download directory. This is not compatible with the official downloader.
