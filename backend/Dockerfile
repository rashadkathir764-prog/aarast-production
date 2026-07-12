FROM node:22-alpine AS build

WORKDIR /app

RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
COPY tsconfig*.json ./
COPY scripts/clean-dist.cjs ./scripts/clean-dist.cjs
COPY src ./src

RUN npx prisma generate
RUN npm run build

# Strip dev dependencies, then regenerate the Prisma client because prune
# can drop the generated engines under node_modules/.prisma. The prisma CLI
# lives in production dependencies because the container runs
# `migrate deploy` at startup.
RUN npm prune --omit=dev
RUN npx prisma generate

FROM node:22-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production

RUN apk add --no-cache openssl

COPY --from=build /app/package*.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/dist ./dist

USER node

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
