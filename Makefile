.PHONY : all

all: downloader indexer

downloader-dev:
	crystal build --define preview_mt pwned-passwords-downloader.cr

downloader:
	crystal build --define preview_mt --release pwned-passwords-downloader.cr

indexer:
	crystal build --release pwned-passwords-indexer.cr

strip:
	if [ -f pwned-passwords-downloader ]; then strip --strip-unneeded pwned-passwords-downloader; fi
	if [ -f pwned-passwords-indexer ]; then strip --strip-unneeded pwned-passwords-indexer; fi

format:
	crystal tool format

clean:
	rm -f pwned-passwords-downloader pwned-passwords-downloader.dwarf
	rm -f pwned-passwords-indexer pwned-passwords-indexer.dwarf
