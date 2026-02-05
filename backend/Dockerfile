FROM node:20-alpine AS builder

# Install build dependencies for native modules (bcrypt, sqlite3)
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine

# Runtime dependencies for native modules
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy built files and dependencies
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/serviceAccountKey.json ./

ENV PORT=3005
ENV NODE_ENV=production
EXPOSE 3005

CMD ["node", "dist/src/main.js"]
