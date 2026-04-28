# syntax=docker/dockerfile:1.7
#
# Multi-arch build. BuildKit auto-supplies TARGETARCH ("amd64" or "arm64").
# docpars only ships musl for x86_64; the aarch64 build is GNU-libc, so on
# Alpine arm64 we install `gcompat` to provide a glibc shim.
FROM --platform=$BUILDPLATFORM alpine:3.23 AS docpars

ARG TARGETARCH
ENV DOCPARS_VERSION=v0.3.0

RUN apk add --no-cache wget && \
  case "$TARGETARCH" in \
    amd64) DOCPARS_TARGET="x86_64-unknown-linux-musl" ;; \
    arm64) DOCPARS_TARGET="aarch64-unknown-linux-gnu" ;; \
    *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
  esac && \
  wget -q "https://github.com/denisidoro/docpars/releases/download/${DOCPARS_VERSION}/docpars-${DOCPARS_VERSION}-${DOCPARS_TARGET}.tar.gz" \
    -O /tmp/docpars.tar.gz && \
  tar xzf /tmp/docpars.tar.gz -C /usr/local/bin/ && \
  chmod +x /usr/local/bin/docpars

FROM alpine:3.23 AS final

ARG TARGETARCH

COPY --from=docpars /usr/local/bin/docpars /usr/local/bin/docpars

# bash, curl, jq are required by the action.
# gcompat provides glibc shims so the docpars aarch64-gnu binary can run on Alpine arm64.
RUN apk add --no-cache bash curl jq && \
  if [ "$TARGETARCH" = "arm64" ]; then apk add --no-cache gcompat; fi

COPY entrypoint.sh /entrypoint.sh

COPY src /src

ENTRYPOINT ["/entrypoint.sh"]
