FROM node:22-alpine AS build

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

FROM nginx:1.27-alpine AS runtime

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

LABEL org.opencontainers.image.revision="${AARAST_GIT_REVISION}"

# Placed under templates/ so the image entrypoint runs envsubst on it,
# injecting ${API_ORIGIN} into the CSP connect-src at container start.
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
