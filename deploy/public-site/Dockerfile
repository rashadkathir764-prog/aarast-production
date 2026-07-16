FROM nginx:1.31.3-alpine@sha256:7068961d45b07b2af510ac002e9daa63a1d3eba2111202d6768798690800fffd

COPY index.html contact.html privacy.html invite.html /usr/share/nginx/html/
COPY script.js invite.js style.css invite.css invite-preview.png /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -T 2 -O /dev/null http://127.0.0.1/ || exit 1

EXPOSE 80
