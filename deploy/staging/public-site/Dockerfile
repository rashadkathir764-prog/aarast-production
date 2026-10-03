FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS build
WORKDIR /build
COPY public-site /build/source
COPY staging/public-site/build.mjs /build/build.mjs
ARG STAGING_INVITE_ORIGIN
ARG STAGING_QA_INVITE_HOST
ARG STAGING_QA_APPLICATION_ID
ARG STAGING_QA_CERT_FINGERPRINT
ARG STAGING_ROUTE_PROFILE=isolated
ENV STAGING_ROUTE_PROFILE=$STAGING_ROUTE_PROFILE
ENV STAGING_INVITE_ORIGIN=$STAGING_INVITE_ORIGIN
ENV STAGING_QA_INVITE_HOST=$STAGING_QA_INVITE_HOST
ENV STAGING_QA_APPLICATION_ID=$STAGING_QA_APPLICATION_ID
ENV STAGING_QA_CERT_FINGERPRINT=$STAGING_QA_CERT_FINGERPRINT
RUN node /build/build.mjs /build/source /build/output

FROM nginx:1.31.3-alpine@sha256:7068961d45b07b2af510ac002e9daa63a1d3eba2111202d6768798690800fffd
ARG AARAST_GIT_REVISION
LABEL org.opencontainers.image.revision="${AARAST_GIT_REVISION}"
COPY --from=build /build/output/ /usr/share/nginx/html/
RUN cp /usr/share/nginx/html/nginx.conf /etc/nginx/conf.d/default.conf && \
    rm /usr/share/nginx/html/nginx.conf
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -T 2 -O /dev/null http://127.0.0.1/healthz || exit 1
EXPOSE 80
