FROM public.ecr.aws/docker/library/node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps
COPY tsconfig*.json nest-cli.json eslint.config.js ./
COPY src ./src
RUN npm run build

FROM public.ecr.aws/docker/library/node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/package*.json ./
RUN npm ci --omit=dev --legacy-peer-deps
COPY --from=build /app/dist ./dist
CMD ["node", "dist/main.js"]
