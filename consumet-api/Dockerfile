FROM node:20-alpine

# Install build dependencies for native modules
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev for ts-node)
RUN npm ci

# Copy source code
COPY . .

# Set environment variables
ENV PORT=3004
ENV NODE_ENV=production

EXPOSE 3004

# Run with ts-node as the project uses TypeScript directly
CMD ["npx", "ts-node", "src/main.ts"]
