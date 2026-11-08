# tooler: HTML overview of tool versions and available updates

FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

LABEL org.opencontainers.image.title="tooler"
LABEL org.opencontainers.image.description="HTML overview of tool versions and available updates"
LABEL org.opencontainers.image.vendor="tuxpeople"
LABEL org.opencontainers.image.source="https://github.com/tuxpeople/tooler"

# hadolint ignore=DL3018
RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates curl jq yq && \
    adduser -D -u 1000 -h /config tooler

# /config: config.yaml (example included), /defaults: HTML header/footer,
# /output: index.html (mount a writable volume with a read-only root)
COPY --chown=root:root root/ /
RUN chown tooler:tooler /output

USER 1000
WORKDIR /output

# Runs once and exits, e.g. as a Kubernetes CronJob
ENTRYPOINT ["/app/tooler.sh"]
