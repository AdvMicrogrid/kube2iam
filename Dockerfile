FROM golang:1.11-alpine as builder
RUN set -e; \
    apk --no-cache add git; \
    go get -v -u github.com/Masterminds/glide; \
    go get -v -u github.com/githubnemo/CompileDaemon; \
    go get -v -u github.com/alecthomas/gometalinter; \
    go get -v -u github.com/jstemmer/go-junit-report; \
    go get -v github.com/mattn/goveralls; \
    gometalinter --install --update;
WORKDIR /go/src/github.com/jtblin/kube2iam
COPY . .
RUN set -e; \
    glide install --strip-vendor; \
    go build -o build/bin/linux/kube2iam github.com/jtblin/kube2iam/cmd


FROM alpine:3.8
RUN apk --no-cache add \
    ca-certificates \
    iptables
COPY --from=builder /go/src/github.com/jtblin/kube2iam/build/bin/linux/kube2iam /bin/kube2iam

ENTRYPOINT ["kube2iam"]
