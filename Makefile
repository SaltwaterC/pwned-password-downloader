.PHONY : all

all: downloader-release

downloader-dev:
	crystal build --define preview_mt pwned-password-downloader.cr

downloader:
	crystal build --define preview_mt --release pwned-password-downloader.cr

downloader-static:
	crystal build --define preview_mt --release --static pwned-password-downloader.cr

downloader-release:
	docker build -v `pwd`:/build .
	$(MAKE) strip

strip:
	if [ -f pwned-password-downloader ]; then strip --strip-unneeded pwned-password-downloader; fi

format:
	crystal tool format

clean:
	rm -f pwned-password-downloader pwned-password-downloader.dwarf
