# Spacedock Docker Image Build Tools

This directory contains tools and scripts for building and publishing Docker images for the Spacedock project.

## Directory Location

These build tools are located in the `docker/build/` directory, alongside the Dockerfile in the same docker directory for easy management.

## File Description

- `build.sh` - Bash script for Linux/macOS environments
- `build.env.example` - Example environment variable configuration file
- `docker-compose.build-local.yaml` - Docker Compose configuration for local builds
- `Makefile` - Make configuration file providing convenient build commands
- `README.md` - This documentation

## Supported Images

This tool can build images for the following Spacedock services:

- **api** (Spacedock) - Main API service
- **proxy** - Proxy service
- **runner** - Runner service
- **docs** - Documentation service

## Quick Start

### 1. Using Make (Recommended)

```bash
# Show help information
make help

# Build all images locally
make build

# Build and push to repository
make build-push VERSION=0.0.1

# Quick development build (single platform, no cache)
make quick

# Build individual services
make api
make proxy
make runner
make docs
```

### 2. Using Scripts Directly

#### Linux/macOS

```bash
# Enter build directory
cd docker/build

# Basic build
./build.sh --version 0.0.1

# Build and push to GitHub Container Registry
./build.sh \
  --platform linux/amd64 \
  --registry ghcr.io \
  --namespace galaxyeye \
  --version 0.0.1 \
  --push

# Build only API and Proxy services
./build.sh \
  --services api,proxy \
  --version 0.0.1
```

### 3. Using Docker Compose

```bash
# Enter build directory
cd docker/build

# Set environment variables
export VERSION=0.0.1
export REGISTRY=ghcr.io

# Build all images
docker-compose -f docker-compose.build-local.yaml build

# Build specific services
docker-compose -f docker-compose.build-local.yaml build api proxy
```

### 4. Using Environment Variables

Create `.env` file (based on `build.env.example`):

```bash
# Copy example configuration
cp build.env.example .env

# Edit configuration
vim .env
```

Then use the script:

```bash
# Script will automatically read .env file
./build.sh
```

## Configuration Options

### Environment Variables

| Variable Name | Default Value | Description |
|---------------|---------------|-------------|
| `REGISTRY` | `docker.io` | Docker image registry address |
| `NAMESPACE` | `galaxyeye` | Image namespace |
| `VERSION` | `latest` | Image version tag |
| `PLATFORM` | `linux/amd64,linux/arm64` | Build platforms |
| `SERVICES` | `api,proxy,runner,docs` | Services to build |
| `PUSH` | `false` | Whether to push to repository |
| `NO_BUILD_CACHE` | `false` | Whether to disable build cache |
| `VERBOSE` | `false` | Whether to show verbose logs |

### Command Line Arguments

#### Bash Script (`build.sh`)

```bash
Options:
    -r, --registry REGISTRY     Docker image registry address
    -n, --namespace NAMESPACE   Image namespace
    -v, --version VERSION       Image version tag
    -p, --platform PLATFORM    Target platforms
    -s, --services SERVICES     List of services to build, comma-separated
    --push                      Push images to repository
    --no-cache                  Don't use build cache
    --verbose                   Show verbose logs
    -h, --help                  Show help information
```

## Common Use Cases

### Development Environment

```bash
# Quick local build (single platform, suitable for development testing)
make build-dev

# Or
./build.sh --version 0.0.1 --platform linux/amd64
```

### Production Environment

```bash
# Multi-platform build and push to Docker Hub
make build-prod VERSION=0.0.1

# Push to GitHub Container Registry
make github VERSION=0.0.1

# Push to private registry
make build-push \
  REGISTRY=your-registry \
  NAMESPACE=your-namespace \
  VERSION=0.0.1
```

### CI/CD Environment

```bash
# Use environment variables in CI/CD pipeline
export REGISTRY=ghcr.io
export NAMESPACE=${{ github.repository_owner }}
export VERSION=${{ github.ref_name }}
export PUSH=true

./build.sh
```

### Building Specific Services

```bash
# Build only API service
make build-single SERVICE=api VERSION=0.0.1

# Build multiple but not all services
./build.sh --services api,proxy --version 0.0.1
```

## Build Optimization

### Using Build Cache

By default, Docker build cache is used to accelerate builds. If you need to rebuild completely:

```bash
# Disable cache
./build.sh --no-cache

# Or
make quick  # includes --no-cache
```

### Multi-platform Builds

For production environments, it's recommended to build multi-platform images:

```bash
# Multi-platform builds require Docker Buildx
./build.sh --platform linux/amd64,linux/arm64
```

If Docker Buildx is not available, the script will automatically downgrade to single-platform builds.

### Parallel Builds

The script supports parallel builds of multiple services to improve efficiency. All services will start building simultaneously, but each service's build process is independent.

## Troubleshooting

### Docker Related Issues

```bash
# Check Docker status
docker version
docker buildx version

# Clean build cache
make clean

# Complete cleanup (use with caution)
make clean-all
```

### Docker Registry Mirror

If you encounter network timeout issues when pulling Docker images (like `TLS handshake timeout`), you can configure Docker registry mirrors to speed up image downloads:

1. **Configure Docker daemon** (recommended):

   Create or edit `/etc/docker/daemon.json`:

   ```json
   {
     "registry-mirrors": [
       "https://docker.m.daocloud.io"
     ]
   }
   ```

2. **Restart Docker service**:

   ```bash
   sudo systemctl restart docker
   ```

3. **Verify configuration**:

   ```bash
   docker info | grep "Registry Mirrors" -A 1
   ```

**Note**: This configuration is particularly useful for users in China where direct access to Docker Hub may be slow or unstable.

### Build Failures

1. **Insufficient Memory**: Reduce the number of services being built in parallel
2. **Network Issues**: Check network connection and proxy settings
3. **Permission Issues**: Ensure Docker access permissions
4. **Platform Not Supported**: Check if target platform is supported

### Push Failures

1. **Authentication Issues**: Ensure logged in to image registry

   ```bash
   docker login
   # Or for GitHub Container Registry
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

2. **Permission Issues**: Ensure push permissions to target registry

3. **Image Name Issues**: Check if image name format is correct

## Best Practices

1. **Version Management**: Use semantic versioning (e.g., 0.0.1)
2. **Tagging Strategy**: Use different tags for different environments (dev, staging, prod)
3. **Cache Utilization**: Configure appropriate cache strategies in CI/CD
4. **Security Scanning**: Perform security scans on images before pushing
5. **Resource Cleanup**: Regularly clean up unnecessary images and cache

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Push Docker Images

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push images
        run: |
          cd docker/build
          ./build.sh \
            --registry ghcr.io \
            --namespace ${{ github.repository_owner }} \
            --version ${GITHUB_REF#refs/tags/} \
            --push
```

### GitLab CI Example

```yaml
build-images:
  stage: build
  script:
    - cd docker/build
    - ./build.sh
      --registry $CI_REGISTRY
      --namespace $CI_PROJECT_NAMESPACE
      --version $CI_COMMIT_TAG
      --push
  only:
    - tags
```

## Contributing

If you find issues or have improvement suggestions, please submit an Issue or Pull Request.

## License

This project follows the same license as the main Spacedock project.
