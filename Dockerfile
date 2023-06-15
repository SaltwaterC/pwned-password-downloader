FROM  crystallang/crystal:1.8.2-alpine
WORKDIR /build
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache
RUN shards install
RUN make downloader-static
