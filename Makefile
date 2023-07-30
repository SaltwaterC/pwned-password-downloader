.DEFAULT_GOAL : all
.PHONY : all release static macos format clean macos-arch

all: release

dev: format $(shell find src -type f -name "*.cr")
	crystal build --define preview_mt ./src/pwned-password-downloader.cr -o $@

dynamic: format $(shell find src -type f -name "*.cr")
	crystal build --define preview_mt --release ./src/pwned-password-downloader.cr -o $@

static: format
	crystal build --define preview_mt --release --static ./src/pwned-password-downloader.cr -o pwned-password-downloader-linux-amd64

pwned-password-downloader-linux-amd64: $(shell find src -type f -name "*.cr")
	docker run --rm --volume `pwd`:/build crystallang/crystal:1.9.2-alpine make -C build static
	docker run --rm --volume `pwd`:/build crystallang/crystal:1.9.2-alpine strip /build/$@

release: pwned-password-downloader-linux-amd64

# https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary
# https://crystal-lang.org/reference/1.9/syntax_and_semantics/cross-compilation.html

macos-arch: format $(shell find src -type f -name "*.cr")
	crystal build --define preview_mt --release --cross-compile --target $(ARCH)-apple-macos11 -o downloader_$(ARCH) ./src/pwned-password-downloader.cr
	$(CC) -target $(ARCH)-apple-macos11 downloader_$(ARCH).o -o downloader_$(ARCH) -rdynamic \
	-L/opt/crystal/embedded/lib -lz -lpcre -lgc -levent_pthreads -levent -liconv \
	$(BREW_LIB_PATH)/libssl.a $(BREW_LIB_PATH)/libcrypto.a
	strip downloader_$(ARCH)

downloader_x86_64:
	$(MAKE) macos-arch ARCH=x86_64 BREW_LIB_PATH=/usr/local/opt/openssl/lib

downloader_arm64:
	$(MAKE) macos-arch ARCH=arm64 BREW_LIB_PATH=/opt/armbrew/lib

pwned-password-downloader-darwin-universal: downloader_x86_64 downloader_arm64
	lipo -create -output pwned-password-downloader-darwin-universal downloader_x86_64 downloader_arm64
	@# avoid getting killed by GateKeeper on ARM Macs
	codesign -s - -f pwned-password-downloader-darwin-universal

macos: pwned-password-downloader-darwin-universal

format:
	crystal tool format

clean:
	rm -f pwned-password-downloader-* *.dwarf downloader_* downloader_*.o dev dynamic
