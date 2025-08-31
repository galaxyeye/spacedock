FROM docker:28.2.2-dind-alpine3.22 AS builder

# Install nodejs
RUN --mount=type=cache,target=/var/cache/apk \
  apk --update add nodejs=22.16.0-r2 npm bash
RUN npm install -g corepack && corepack enable

COPY --from=golang:1.23.5-alpine /usr/local/go/ /usr/local/go/

ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /spacedock

# Copy package files first for better caching
COPY package.json yarn.lock ./
COPY apps/*/package.json apps/*/
COPY libs/*/package.json libs/*/
COPY docker/runner-entrypoint.sh docker/

# Install dependencies
RUN --mount=type=cache,target=/root/.yarn \
    yarn install --frozen-lockfile

COPY . .

# Build arguments
ARG PUBLIC_WEB_URL=https://platon.ai
ARG PUBLIC_ALGOLIA_APP_ID
ARG PUBLIC_ALGOLIA_API_KEY
ARG VERSION=0.0.1

# Build environment variables
ENV PUBLIC_WEB_URL=${PUBLIC_WEB_URL} \
    PUBLIC_ALGOLIA_APP_ID=${PUBLIC_ALGOLIA_APP_ID} \
    PUBLIC_ALGOLIA_API_KEY=${PUBLIC_ALGOLIA_API_KEY} \
    VERSION=${VERSION}

# Build with optimal cache strategy - hybrid approach
# Step 0: Ensure all dependencies are available (critical step)
RUN --mount=type=cache,target=/root/.yarn \
    yarn install --immutable

# Step 1: Build fast JS/TS components together (better parallelization)
RUN --mount=type=cache,target=/root/.cache/nx \
    NX_DAEMON=false yarn nx run-many --target=build --projects=api,dashboard,tag:lib --parallel --configuration=production

# Step 2: Build docs separately (independent, often changed) - Skip due to Nx daemon issues
RUN --mount=type=cache,target=/root/.cache/nx \
    NX_DAEMON=false yarn nx build docs --configuration=production

# Step 3: Build Go Runner separately (largest, most cache-sensitive)
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    NX_DAEMON=false yarn nx build runner --configuration=production

# Step 4: Build remaining Go components together (similar dependencies)
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    NX_DAEMON=false yarn nx run-many --target=build --projects=proxy,daemon,cli --parallel --configuration=production

# Runtime stage
FROM docker:28.2.2-dind-alpine3.22 AS spacedock

# Install only runtime dependencies
RUN --mount=type=cache,target=/var/cache/apk \
  apk --update add nodejs=22.16.0-r2 npm bash
RUN npm install -g corepack && corepack enable

WORKDIR /spacedock

# Copy only built artifacts from builder stage
COPY --from=builder /spacedock/dist ./dist
COPY --from=builder /spacedock/package.json ./package.json
COPY --from=builder /spacedock/yarn.lock ./yarn.lock
COPY --from=builder /spacedock/.yarnrc.yml ./.yarnrc.yml
COPY --from=builder /spacedock/nx.json ./nx.json
COPY --from=builder /spacedock/node_modules ./node_modules
# Copy apps/api directory for migrations
COPY --from=builder /spacedock/apps/api ./apps/api
# Copy TypeScript config files for migrations
COPY --from=builder /spacedock/tsconfig.base.json ./tsconfig.base.json
# Copy docker directory for runner entrypoint
COPY --from=builder /spacedock/docker ./docker

RUN mkdir -p /etc/docker && echo '{"iptables": false, "ip-forward": false, "ip-masq": false, "userland-proxy": false,"insecure-registries": ["localhost:6000"]}' > /etc/docker/daemon.json

# Application Configuration
ENV PORT=3000 \
    ENVIRONMENT=dev \
    DEFAULT_SNAPSHOT=ubuntu:22.04 \
    DASHBOARD_URL=http://localhost:3000/dashboard \
    MAX_AUTO_ARCHIVE_INTERVAL=43200 \
    MAINTENANCE_MODE=false

# Database Configuration
ENV DB_HOST=db \
    DB_PORT=5432 \
    DB_USERNAME=user \
    DB_PASSWORD=pass \
    DB_DATABASE=spacedock

# Redis Configuration
ENV REDIS_HOST=redis \
    REDIS_PORT=6379

# OIDC Configuration (using local dex)
ENV OIDC_ISSUER_BASE_URL=http://localhost:5556/dex \
    OIDC_CLIENT_ID=spacedock \
    OIDC_AUDIENCE=spacedock \
    OIDC_MANAGEMENT_API_ENABLED= \
    OIDC_MANAGEMENT_API_CLIENT_ID= \
    OIDC_MANAGEMENT_API_CLIENT_SECRET= \
    OIDC_MANAGEMENT_API_AUDIENCE=

# Analytics Configuration
ENV POSTHOG_API_KEY=phc_bYtEsdMDrNLydXPD4tufkBrHKgfO2zbycM30LOowYNv \
    POSTHOG_HOST=https://d18ag4dodbta3l.cloudfront.net \
    POSTHOG_ENVIRONMENT=local

# Registry Configuration
ENV TRANSIENT_REGISTRY_URL=http://localhost:6000 \
    TRANSIENT_REGISTRY_ADMIN=admin \
    TRANSIENT_REGISTRY_PASSWORD=password \
    TRANSIENT_REGISTRY_PROJECT_ID=spacedock \
    INTERNAL_REGISTRY_URL=http://localhost:6000 \
    INTERNAL_REGISTRY_ADMIN=admin \
    INTERNAL_REGISTRY_PASSWORD=password \
    INTERNAL_REGISTRY_PROJECT_ID=spacedock

# SMTP Configuration
ENV SMTP_HOST=maildev \
    SMTP_PORT=1025 \
    SMTP_USER= \
    SMTP_PASSWORD= \
    SMTP_SECURE= \
    SMTP_EMAIL_FROM="Platon AI <no-reply@platon.ai>"

# S3 Configuration
ENV S3_ENDPOINT=http://minio:9000 \
    S3_STS_ENDPOINT=http://minio:9000/minio/v1/assume-role \
    S3_REGION=us-east-1 \
    S3_ACCESS_KEY=minioadmin \
    S3_SECRET_KEY=minioadmin \
    S3_DEFAULT_BUCKET=spacedock \
    S3_ACCOUNT_ID=/ \
    S3_ROLE_NAME=/

# Observability Configuration
ENV OTEL_ENABLED=true \
    OTEL_COLLECTOR_URL=http://jaeger:4318/v1/traces

# Proxy Configuration
ENV PROXY_DOMAIN=proxy.localhost:4000 \
    PROXY_PROTOCOL=http \
    PROXY_API_KEY=super_secret_key \
    PROXY_TEMPLATE_URL=http://{{PORT}}-{{sandboxId}}.proxy.localhost:4000

# Default Runner Configuration
ENV DEFAULT_RUNNER_DOMAIN=localhost:3003 \
    DEFAULT_RUNNER_API_URL=http://localhost:3003 \
    DEFAULT_RUNNER_PROXY_URL=http://localhost:3003 \
    DEFAULT_RUNNER_API_KEY=secret_api_token \
    DEFAULT_RUNNER_CPU=4 \
    DEFAULT_RUNNER_MEMORY=8 \
    DEFAULT_RUNNER_DISK=50 \
    DEFAULT_RUNNER_GPU=0 \
    DEFAULT_RUNNER_GPU_TYPE=none \
    DEFAULT_RUNNER_CAPACITY=100 \
    DEFAULT_RUNNER_REGION=us \
    DEFAULT_RUNNER_CLASS=small

# ENTRYPOINT ["sh", "-c", "dockerd-entrypoint.sh & node dist/apps/api/main.js"]
ENTRYPOINT ["sh", "-c", "dockerd-entrypoint.sh & yarn migration:run && node dist/apps/api/main.js"]

FROM alpine:3.18 AS proxy

WORKDIR /usr/local/bin

COPY --from=spacedock /spacedock/dist/apps/proxy spacedock-proxy

RUN chmod +x spacedock-proxy

# Spacedock API Configuration
ENV DAYTODAY_API_URL=http://localhost:3000/api
# Spacedock API URL for compatibility
ENV SPACEDOCK_API_URL=http://localhost:3000/api

# Proxy Configuration
ENV PROXY_PORT=4000 \
    PROXY_DOMAIN=proxy.localhost:4000 \
    PROXY_API_KEY=super_secret_key \
    PROXY_PROTOCOL=http

# OIDC Configuration
ENV OIDC_CLIENT_ID=spacedock \
    OIDC_CLIENT_SECRET= \
    OIDC_ISSUER_BASE_URL=http://localhost:5556/dex \
    OIDC_DOMAIN=http://localhost:5556/dex \
    OIDC_AUDIENCE=spacedock

# Redis Configuration
ENV REDIS_HOST=redis \
    REDIS_PORT=6379

ENTRYPOINT ["spacedock-proxy"]

FROM docker:28.2.2-dind-alpine3.22 AS runner

# Install dumb-init to handle signals and reap zombie processes
RUN apk add --no-cache dumb-init

WORKDIR /usr/local/bin

COPY --from=spacedock /spacedock/docker/runner-entrypoint.sh /usr/local/bin/runner-entrypoint.sh
COPY --from=spacedock /spacedock/dist/apps/runner spacedock-runner

RUN chmod +x spacedock-runner && chmod +x /usr/local/bin/runner-entrypoint.sh

RUN mkdir -p /etc/docker && echo '{"iptables": false, "ip-forward": false, "ip-masq": false, "userland-proxy": false,"insecure-registries": ["localhost:6000"]}' > /etc/docker/daemon.json

# Application Configuration
ENV ENVIRONMENT=development \
    RESOURCE_LIMITS_DISABLED=true

# API Configuration
ENV API_PORT=3003 \
    API_TOKEN=secret_api_token

# Spacedock Configuration
ENV SPACEDOCK_BINARY_PATH=/workspaces/spacedock/dist/apps/daemon-amd64 \
    LOG_FILE_PATH=/home/spacedock/runner/runner.log

# AWS Configuration
ENV AWS_ENDPOINT_URL=http://minio:9000 \
    AWS_REGION=us-east-1 \
    AWS_ACCESS_KEY_ID=minioadmin \
    AWS_SECRET_ACCESS_KEY=minioadmin \
    AWS_DEFAULT_BUCKET=spacedock

ENTRYPOINT ["dumb-init", "/usr/local/bin/runner-entrypoint.sh"]

# FROM node:22-alpine AS docs

# WORKDIR /spacedock

# COPY --from=spacedock /spacedock/node_modules node_modules
# COPY --from=spacedock /spacedock/dist/apps/docs dist/apps/docs
# COPY --from=spacedock /spacedock/apps/docs/server dist/apps/docs/server

# WORKDIR /spacedock/dist/apps/docs

# ENTRYPOINT ["sh", "-c", "node server/index.mjs"]
