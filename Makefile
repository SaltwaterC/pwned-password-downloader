.PHONY : all

all:
	crystal build --release pwned-passwords-indexer.cr

clean:
	rm -f pwned-passwords-indexer pwned-passwords-indexer.dwarf
