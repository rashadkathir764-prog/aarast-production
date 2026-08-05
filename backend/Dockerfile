FROM node@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS build

WORKDIR /app

RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
COPY tsconfig*.json ./
COPY scripts/clean-dist.cjs ./scripts/clean-dist.cjs
COPY scripts/prod/provision-admin.cjs ./scripts/prod/provision-admin.cjs
COPY scripts/prod/assert-database-identity.cjs ./scripts/prod/assert-database-identity.cjs
COPY scripts/prod/assert-firebase-credentials.cjs ./scripts/prod/assert-firebase-credentials.cjs
COPY src ./src

RUN npx prisma generate
RUN npm run build

# Strip dev dependencies, then regenerate the Prisma client because prune
# can drop the generated engines under node_modules/.prisma. The prisma CLI
# lives in production dependencies because the container runs
# `migrate deploy` at startup.
RUN npm prune --omit=dev
RUN npx prisma generate

FROM node@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS runtime

ARG AARAST_GIT_REVISION=development-unversioned

WORKDIR /app

ENV NODE_ENV=production

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

RUN apk add --no-cache openssl
# The Node base image ships npm 10.9.8, which currently carries vulnerable
# bundled packages (brace-expansion, ip-address, picomatch, sigstore, and tar). Keep the
# runtime toolchain on the fixed npm release used by the supply-chain gate.
RUN npm install --global npm@12.0.2 --no-fund --no-audit \
    && mkdir -p /tmp/npm-fix \
    && npm pack brace-expansion@5.0.9 --pack-destination /tmp/npm-fix --silent \
    && npm pack ip-address@10.3.1 --pack-destination /tmp/npm-fix --silent \
    && rm -rf /usr/local/lib/node_modules/npm/node_modules/brace-expansion \
    && tar -xzf /tmp/npm-fix/brace-expansion-5.0.9.tgz -C /usr/local/lib/node_modules/npm/node_modules \
    && mv /usr/local/lib/node_modules/npm/node_modules/package /usr/local/lib/node_modules/npm/node_modules/brace-expansion \
    && rm -rf /usr/local/lib/node_modules/npm/node_modules/ip-address \
    && tar -xzf /tmp/npm-fix/ip-address-10.3.1.tgz -C /usr/local/lib/node_modules/npm/node_modules \
    && mv /usr/local/lib/node_modules/npm/node_modules/package /usr/local/lib/node_modules/npm/node_modules/ip-address \
    && rm -rf /tmp/npm-fix \
    && npm cache clean --force

COPY --from=build /app/package*.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/scripts/prod/provision-admin.cjs ./scripts/prod/provision-admin.cjs
COPY --from=build /app/scripts/prod/assert-database-identity.cjs ./scripts/prod/assert-database-identity.cjs
COPY --from=build /app/scripts/prod/assert-firebase-credentials.cjs ./scripts/prod/assert-firebase-credentials.cjs
COPY --from=build /app/dist ./dist

USER node

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
