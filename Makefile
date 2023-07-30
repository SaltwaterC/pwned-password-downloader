.DEFAULT_GOAL : all
.PHONY : all release static macos strip format clean

all: release

.gen/version.cr: shard.yml
	crystal run tools/version.cr

dev: .gen/version.cr pwned-password-downloader.cr $(shell find src -type f -name "*.cr")
	crystal build --define preview_mt pwned-password-downloader.cr -o dev

dynamic: .gen/version.cr pwned-password-downloader.cr $(shell find src -type f -name "*.cr")
	crystal build --define preview_mt --release pwned-password-downloader.cr -o dynamic

static:
	crystal build --define preview_mt --release --static pwned-password-downloader.cr -o pwned-password-downloader-linux-amd64

release:
	docker build -v `pwd`:/build .
	$(MAKE) strip

# https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary
# https://crystal-lang.org/reference/1.9/syntax_and_semantics/cross-compilation.html
macos:
	crystal build --define preview_mt --release --cross-compile --target x86_64-apple-macos11 -o downloader_x86_64 pwned-password-downloader.cr
	$(CC) -target x86_64-apple-macos11 downloader_x86_64.o -o downloader_x86_64 -rdynamic -L/opt/crystal/embedded/lib -lz -lpcre -lgc -levent_pthreads -levent -liconv /usr/local/opt/openssl/lib/libssl.a /usr/local/opt/openssl/lib/libcrypto.a
	crystal build --define preview_mt --release --cross-compile --target arm64-apple-macos11 -o downloader_arm64 pwned-password-downloader.cr
	$(CC) -target arm64-apple-macos11 downloader_arm64.o -o downloader_arm64  -rdynamic -L/opt/crystal/embedded/lib -lz -lpcre -lgc -levent_pthreads -levent -liconv /opt/armbrew/lib/libssl.a /opt/armbrew/lib/libcrypto.a
	strip downloader_x86_64
	strip downloader_arm64
	lipo -create -output pwned-password-downloader-darwin-universal downloader_x86_64 downloader_arm64
	# avoid getting killed by GateKeeper on ARM Macs
	codesign -s - -f pwned-password-downloader-darwin-universal

strip:
	if [ -f pwned-password-downloader-linux-amd64 ]; then strip --strip-unneeded pwned-password-downloader-linux-amd64; fi

format:
	crystal tool format

clean:
	rm -f pwned-password-downloader-* pwned-password-downloader-*.dwarf downloader_* downloader_*.o dev dynamic .gen/*
