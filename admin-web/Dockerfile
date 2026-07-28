FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS build

WORKDIR /app

ARG VITE_API_BASE_URL=https://aarast-api.shadowgardn.com
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

COPY package*.json ./
RUN npm ci

COPY index.html ./
COPY tsconfig*.json ./
COPY vite.config.ts ./
COPY scripts ./scripts
COPY src ./src

RUN npm run build

FROM nginx:1.31-alpine-slim@sha256:45b82ed5f285b90d63df07ba70430fdd8f25624b416617d9e6dc93412b2006dc AS runtime

ARG AARAST_GIT_REVISION=development-unversioned

ENV API_ORIGIN=https://aarast-api.shadowgardn.com

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

RUN apk upgrade --no-cache

LABEL org.opencontainers.image.revision="${AARAST_GIT_REVISION}"

# Placed under templates/ so the image entrypoint runs envsubst on it,
# injecting ${API_ORIGIN} into the CSP connect-src at container start.
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY scripts/runtime-config-guard.sh /usr/local/bin/aarast-runtime-config-guard
RUN chmod 0555 /usr/local/bin/aarast-runtime-config-guard
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/aarast-runtime-config-guard"]
CMD ["nginx", "-g", "daemon off;"]
