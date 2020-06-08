FROM pandoc/latex:latest

RUN apk add bash git go jq qpdf

RUN wget https://kindlegen.s3.amazonaws.com/kindlegen_linux_2.6_i386_v2_9.tar.gz && \
  tar zxf kindlegen_linux_2.6_i386_v2_9.tar.gz

RUN go get github.com/ericchiang/pup

COPY cover.* /data/
COPY generate.sh /data/

VOLUME /data/out

CMD ["./generate.sh"]
