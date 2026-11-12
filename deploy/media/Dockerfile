# The local and CI media store (S3-compatible), and its admin client.
#
# MinIO stopped publishing images: since November 2026 `minio/minio` and
# `minio/mc` are refused by Docker Hub and by quay.io ("pull access denied"),
# so a machine without a cached copy, GitHub's runners included, could not
# start the stack. The two release tags the project runs are still in the
# public source, so they are built from it here, at those tags.
#
#   docker compose build media media-init
#
# Production keeps its files in S3 and does not use this image.

FROM golang:1.24-alpine@sha256:8bee1901f1e530bfb4a7850aa7a479d17ae3a18beb6e09064ed54cfd245b7191 AS build
ENV CGO_ENABLED=0
RUN go install -trimpath -ldflags "-s -w" github.com/minio/minio@RELEASE.2025-09-07T16-13-09Z
RUN go install -trimpath -ldflags "-s -w" github.com/minio/mc@RELEASE.2025-07-21T05-28-08Z

FROM alpine:3.22@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f AS minio
# curl is the compose healthcheck's probe.
RUN apk upgrade --no-cache && apk add --no-cache ca-certificates curl
COPY --from=build /go/bin/minio /usr/bin/minio
EXPOSE 9000 9001
ENTRYPOINT ["/usr/bin/minio"]

FROM alpine:3.22@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f AS mc
RUN apk upgrade --no-cache && apk add --no-cache ca-certificates
COPY --from=build /go/bin/mc /usr/bin/mc
ENTRYPOINT ["/usr/bin/mc"]
