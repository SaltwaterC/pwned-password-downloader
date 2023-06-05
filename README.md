# pwned-passwords-tools

- pwned-passowrds-downloader - cross-platform alternative to official tool that doesn't require a runtime.
- pwned-passwords-indexer - used by the old archived pwned-password.txt lists that used to be available.

## pwned-passwords-downloader

Work in progress! Read: buggy, particularly concurrent code.

Cross-platform alternative to official [PwnedPasswordsDownloader](https://github.com/HaveIBeenPwned/PwnedPasswordsDownloader). While .NET Core runtime is available on more platforms these days, this allows the binaries to run without any particular runtime.

While it implements a parallelism option, it may not work exactly the same as the official `PwnedPasswordsDownloader`. This sets the number of fibers (coroutines) to run concurrently. The binary must be built with `preview_mt` to enable Crystal runtime's parallelism support and the default numbers of system theads (forks really) is set as 4, unless overriden via `CRYSTAL_WORKERS` environment variable. While fibers by themselves may get some benefit without threading while waiting for IO, it won't get the full performance benefit without an appropriate number of threads.

The responses from api.pwnedpasswors.com are gzip compressed and transparently decompressed by default by Crystal's HTTP library.

Supports additional features not available in the official downloader:

 * Saves range ETags to make it easier to verify whether a range file requires update. WIP i.e going to be an optional, ETag checking not yet implemented, lots of wasted disk space due to overhead (will be implemented as SQLite DB).
 * Saves a single specified range in the output directory. Useful if a range fails to download.
 * Basic integrity checks i.e whether all files have been downloaded and their length is non-zero.
 * TODO: option to strip CRLF to keep LF only (UNIX line termination) - shaves off about 0.5 GiB of disk space
 * TODO: option to strip counters - shaves off about 1.1 GiB of disk space

Missing feature from official downloader: single file mode. The single file mode is difficult to work with due to sheer size so it is rather useless by itself without either splitting the file or indexing the file. Both options (splitting and indexing) are time consuming and by default (this tool) or as an option (official downloader) gets the ranges as separate files anyway which are easy to query. Considering that there's no single archive to speed up the download as any tool would still need to send 1048576 requests to api.pwnedpasswords.com to get the ranges, this feature is rather useless by itself.

## pwned-passwords-indexer

These are a set of tools created to speed up the search in large files such as the [Have I Been Pwned downloadable passwords list](https://haveibeenpwned.com/Passwords).

While the tooling has been created for the HIBP files, it is possible to use them for any password file that has the following specifications:

 * the hashes are sorted
 * the hashes are in upper case hex string format

The hashes don't have to be SHA1. While this was not planned, it also supports NTLM hashes as the indexer only reads hash prefixes to determine the ranges.

**Purpose:** offline password auditing.

**Advantages:** the index may be generated in a reasonable time and the original pwned password files may be used.

**Disadvantages:** the index uses extra disk space. It is not the fastest way to search such a large data set. The hash list must be downloaded using `pwned-passwords-downloader` (this repo) or `PwnedPasswordsDownloader` (official tool) which negates any advantages previously offered by the archived list which are not available anymore. While the tooling isn't deprecated, it is a bit of a useless effort to merge all ranges returned by the API only to compute the ranges for offline use.

There are no versioned releases for the tool. Basically the only available version used to index the HIBP pwned-passwords.txt file should work for any version.

To run the macOS Crystal binary you'll need these runtime dependencies:

```bash
brew install bdw-gc
brew install libevent
```

The tool has two implementations: the original Ruby implementation, and a Crystal implementation ported from Ruby for performance reasons since the indexing is O(n) and CPU bound (provided a fast enough disk). However, the number of iterations is based on the number of hashes which is rather large. The Crystal version is roughly 4 times faster.

On older hardware i.e an i7-2860QM running at 2.5 GHz (turbo boost disabled) and a SATA SSD, the indexing of 23 GiB of password file takes under 2:30 minutes. It is significantly faster on recent hardware.

This indexer maps the pwned password file into 65536 buckets based onto the first 4 characters of the hash which are also the file names. The files themselves are stored into 4096 directories which are the first 2 characters from the hash. The format of the file describing the index is:

```yaml
s: start_byte
e: end_byte
```

It is a very compact representation and can be parsed as YAML.

Due to overhead, the size of the index is based on the block size of the filesystem. On a 4 kiB block size, the index takes 256 MiB even though the release archive of the index is under 1 MiB. This is the reason the index doesn't have more buckets - the 5th character of the hash increases the bucket number 16 times and it requires 4GiB of storage, whereas the performance improvements of the search speed are very minimal.
