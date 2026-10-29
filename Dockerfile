# syntax=docker/dockerfile:1.7

# =============================================================================
# Builder stage — installs production dependencies only, on a fresh Node base.
# =============================================================================

FROM node:20-alpine AS builder
#   Do NOT use `node:latest` — we want reproducible builds across the cohort.

WORKDIR /app

COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev

COPY app/ ./

# =============================================================================
# Runtime stage — slim final image. Nothing from builder's caches leaks in.
# =============================================================================

FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app /app

# npm isn't needed at runtime, and its bundled `tar` carries a CRITICAL CVE.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

ENV NODE_ENV=production
EXPOSE 3000

# node:20-alpine has no curl or wget, so probe /health with Node's http module.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "src/index.js"]
