FROM alpine:3.18 as docpars

ENV DOCPARS_VERSION=v0.3.0

RUN apk add --no-cache wget && \
  wget https://github.com/denisidoro/docpars/releases/download/${DOCPARS_VERSION}/docpars-${DOCPARS_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    -O docpars.tar.gz && \
    tar xvfz docpars.tar.gz -C ./ && \
    chmod +x docpars

FROM alpine:3.18 as final

COPY --from=docpars /docpars /usr/local/bin/docpars

RUN apk add --no-cache bash curl jq

COPY entrypoint.sh /entrypoint.sh

COPY src /src

ENTRYPOINT ["/entrypoint.sh"]
