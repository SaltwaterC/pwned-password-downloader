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
