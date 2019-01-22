# pwned-passwords-tools

These are a set of tools created to speed up the search in large files such as the [Have I Been Pwned downloadable passwords list](https://haveibeenpwned.com/Passwords).

While the tooling has been created for the HIBP files, it is possible to use them for any password file that has the following specifications:

 * the hashes are sorted
 * the hashes are in upper case hex string format

The hashes don't have to be SHA1.

## pwned-passwords-indexer

**Purpose:** offline password auditing.

**Advantages:** the index may be generated in a reasonable time and the original pwned password files may be used.

**Disadvantages:** the index uses extra disk space. It is not the fastest way to search such a large data set.

There are no versioned releases for the tool. Basically the only artefact which has a version is the index archive itself having the same version as the HIBP password list.

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

Due to overhead, the size of the index is based on the block size of the filesystem. On a 4 kiB block size, the index takes 256 MiB even though the release archive of the index is under 1 MiB. This is the reason the index doesn't have more buckets - the 5th character of the hash increases the bucket number 16 times and it requires 4GB of storage, whereas the performance improvements of the search speed are very minimal.

As an example, for HIBP v4.7 which has over 551 million passwords and it's 23 GiB in size, the search space is reduced to around 8400 hashes which can be searched in a reasonable time even with an O(n) algorithm.
