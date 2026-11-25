# RA-OP-21: the owner's contact details and legal entity are written into the
# support, terms and privacy pages here, from build arguments; none of them is
# in the repository. Without them the pages keep their {{TOKENS}}, and
# `node render-contact.mjs check` (the release check) fails.
FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS contact
WORKDIR /site
COPY render-contact.mjs privacy.html terms.html support.html /site/
ARG AARAST_LEGAL_ENTITY
ARG AARAST_SUPPORT_EMAIL
ARG AARAST_SUPPORT_WHATSAPP
ARG AARAST_GOVERNING_LAW
RUN node render-contact.mjs render /site /out

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

COPY invite.html invite.js invite.css invite-preview.png rsvp-preview.png public.css assetlinks.json rsvp.html rsvp.js rsvp.css download.html download.js qrcode-generator.js delete-account.html delete-account.js /usr/share/nginx/html/
COPY --from=contact /out/privacy.html /out/terms.html /out/support.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -T 2 -O /dev/null http://127.0.0.1/healthz || exit 1

EXPOSE 80
