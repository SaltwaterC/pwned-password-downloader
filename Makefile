.DEFAULT_GOAL : all
.PHONY : all release static dynamic dev macos format clean macos-arch linux windows shards
crystal_version=1.17.1

all: linux

dev: format $(shell find src -type f -name "*.cr")
	crystal build --define preview_mt ./src/pwned-password-downloader.cr -o $@

dynamic: format $(shell find src -type f -name "*.cr") shards
	crystal build --define preview_mt --release ./src/pwned-password-downloader.cr -o $@

static: format shards
	crystal build --define preview_mt --release --static ./src/pwned-password-downloader.cr -o pwned-password-downloader-linux-amd64

pwned-password-downloader-linux-amd64: $(shell find src -type f -name "*.cr")
	docker run --rm --volume `pwd`:/build crystallang/crystal:$(crystal_version)-alpine make -C build static
	docker run --rm --volume `pwd`:/build crystallang/crystal:$(crystal_version)-alpine strip /build/$@

linux: pwned-password-downloader-linux-amd64

# https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary
# https://crystal-lang.org/reference/1.9/syntax_and_semantics/cross-compilation.html

macos-arch: format $(shell find src -type f -name "*.cr")
	$(eval macos_major := $(shell sw_vers -productVersion | cut -d. -f1))
	mkdir -p build
	cd build && \
	test -f crystal-$(crystal_version)-1-darwin-universal.tar.gz || \
	curl -OL https://github.com/crystal-lang/crystal/releases/download/$(crystal_version)/crystal-$(crystal_version)-1-darwin-universal.tar.gz && \
	cd -
	cd build && \
	test -d crystal-$(crystal_version)-1 || tar -xvf crystal-$(crystal_version)-1-darwin-universal.tar.gz && \
	cd -
	ARCH=$(ARCH) ./tools/bottled-build openssl
	
	crystal build --define preview_mt --release --cross-compile --target $(ARCH)-apple-macos$(macos_major) \
	-o downloader_$(ARCH) ./src/pwned-password-downloader.cr
	
	$(CC) -target $(ARCH)-apple-macos$(macos_major) downloader_$(ARCH).o -o downloader_$(ARCH) -rdynamic \
	-Lbuild/crystal-$(crystal_version)-1/embedded/lib -lz -lpcre2-8 -lgc -levent_pthreads -levent -liconv \
	build/openssl/$(ARCH)/root/lib/libssl.a build/openssl/$(ARCH)/root/lib/libcrypto.a
	
	strip downloader_$(ARCH)

downloader_x86_64:
	$(MAKE) macos-arch ARCH=x86_64

downloader_arm64:
	$(MAKE) macos-arch ARCH=arm64

pwned-password-downloader-darwin-universal: shards downloader_x86_64 downloader_arm64
	lipo -create -output pwned-password-downloader-darwin-universal downloader_x86_64 downloader_arm64
	@# avoid getting killed by GateKeeper on ARM Macs
	codesign -s - -f pwned-password-downloader-darwin-universal

macos: pwned-password-downloader-darwin-universal

# Windows does not yet support preview_mt as of Crystal 1.17.1
pwned-password-downloader.exe: shards
	crystal build --release --static src/pwned-password-downloader.cr

windows: pwned-password-downloader.exe

format:
	crystal tool format

shards:
	shards install

clean:
	rm -rf pwned-password-downloader-* *.dwarf downloader_* downloader_*.o dev dynamic build
