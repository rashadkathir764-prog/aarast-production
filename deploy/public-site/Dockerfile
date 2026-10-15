FROM nginx:1.31.3-alpine@sha256:7068961d45b07b2af510ac002e9daa63a1d3eba2111202d6768798690800fffd

ARG AARAST_GIT_REVISION=development-unversioned

RUN if [ "$AARAST_GIT_REVISION" != "development-unversioned" ]; then \
      if [ "${#AARAST_GIT_REVISION}" -ne 40 ]; then \
        echo "AARAST_GIT_REVISION must be development-unversioned or a full 40-character lowercase Git SHA" >&2; \
        exit 1; \
      fi; \
      case "$AARAST_GIT_REVISION" in \
        *[!0-9a-f]*) \
          echo "AARAST_GIT_REVISION must be development-unversioned or a full 40-character lowercase Git SHA" >&2; \
          exit 1 \
          ;; \
      esac; \
    fi

LABEL org.opencontainers.image.revision="${AARAST_GIT_REVISION}"

COPY invite.html invite.js invite.css invite-preview.png privacy.html support.html public.css assetlinks.json rsvp.html rsvp.js rsvp.css /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -T 2 -O /dev/null http://127.0.0.1/healthz || exit 1

EXPOSE 80
