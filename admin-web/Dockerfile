FROM node:22-alpine AS build

WORKDIR /app

ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

COPY package*.json ./
RUN npm ci

COPY index.html ./
COPY tsconfig*.json ./
COPY vite.config.ts ./
COPY src ./src

RUN npm run build

FROM nginx:1.31-alpine AS runtime

# Placed under templates/ so the image entrypoint runs envsubst on it,
# injecting ${API_ORIGIN} into the CSP connect-src at container start.
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
