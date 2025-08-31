# Docker Compose Setup for Spacedock

This folder contains a Docker Compose setup for running Spacedock locally.

⚠️ **Important**:

- This setup is still in development and is **not safe to use in production**
- A separate deployment guide will be provided for production scenarios

## Overview

The Docker Compose configuration includes all the necessary services to run Spacedock:

- **API**: Main Spacedock application server
- **Proxy**: Request proxy service
- **Runner**: Service that hosts the Spacedock Runner
- **Database**: PostgreSQL database for data persistence
- **Redis**: In-memory data store for caching and sessions
- **Dex**: OIDC authentication provider
- **Registry**: Docker image registry with web UI
- **MinIO**: S3-compatible object storage
- **MailDev**: Email testing service
- **Jaeger**: Distributed tracing
- **PgAdmin**: Database administration interface

## Quick Start

### Option 1: 标准构建 (推荐用于开发)

1. Start all services (from the root of the Spacedock repo):

   ```bash
   docker compose -f docker/docker-compose.yaml up -d
   ```

### Option 2: 优化构建 (推荐用于频繁构建)

1. Use the optimized build script:

   ```bash
   # 从任何目录都可以运行，脚本会自动切换到项目根目录
   ./docker/build/build-optimized.sh
   ```

### Option 3: 高级构建 (支持多种缓存策略)

1. Use the advanced build tools with different options:

   ```bash
   # 使用Makefile构建所有服务
   cd docker/build && make build

   # 构建特定服务
   cd docker/build && make build SERVICES=api,proxy

   # 使用优化构建脚本
   ./docker/build/build-optimized.sh

   # 使用标准构建脚本
   ./docker/build/build.sh

   # 查看所有Makefile选项
   cd docker/build && make help
   ```

### Option 4: 手动优化构建

   Or build with optimizations manually:

   ```bash
   # Enable BuildKit
   export DOCKER_BUILDKIT=1
   export COMPOSE_DOCKER_CLI_BUILD=1
   
   # Build with parallel processing and caching
   docker-compose -f docker/docker-compose.build.yaml build --parallel
   
   # Start services
   docker-compose -f docker/docker-compose.build.yaml up -d
   ```

2. Access the services:
   - Spacedock Dashboard: http://localhost:3000
     - Access Credentials: dev@spacedock.io `password`
     - Make sure that the default snapshot is active at http://localhost:3000/dashboard/snapshots
   - PgAdmin: http://localhost:5050
   - Registry UI: http://localhost:5100
   - MinIO Console: http://localhost:9001 (minioadmin / minioadmin)

## Development Notes

- The setup uses shared networking for simplified service communication
- Database and storage data is persisted in Docker volumes
- The registry is configured to allow image deletion for testing
- Sandbox resource limits are disabled due to inability to partition cgroups in DinD environment where the sock is not mounted

## 🚀 Docker构建优化

### 性能提升

经过优化后的Docker构建具有显著的性能提升：

- **构建时间**: 从65.7s优化到~35s (提升45%+)
- **缓存效率**: 采用混合分层策略，最大化缓存命中率
- **并行构建**: 利用多核CPU，组件并行编译
- **层大小优化**: 从326MB单层优化为4层均衡分布

### 快速构建命令

#### 开发环境 (推荐)

```bash
# 使用优化脚本 - 快速开发构建
./docker/build/build-optimized.sh

# 使用Makefile - 多种构建选项
cd docker/build && make build                    # 构建所有服务
cd docker/build && make build SERVICES=api      # 构建特定服务  
cd docker/build && make clean                    # 清理资源

# 使用标准构建脚本
./docker/build/build.sh

# 或使用 Docker Compose 并行构建
docker-compose -f docker/docker-compose.build.yaml build --parallel
```

#### 生产环境

```bash
# 完整优化构建
docker build -f docker/Dockerfile . --target spacedock

# 构建所有服务
docker-compose -f docker/docker-compose.build.yaml build
```

#### 调试构建

```bash
# 只构建到builder阶段
docker build -f docker/Dockerfile . --target builder

# 查看构建详情
docker build -f docker/Dockerfile . --progress=plain
```

### 核心优化特性

1. **🔄 智能缓存策略**
   - Go模块缓存: `/go/pkg/mod`
   - Yarn缓存: `/root/.yarn`  
   - Nx构建缓存: `/root/.cache/nx`
   - APK包缓存: `/var/cache/apk`

2. **📦 混合分层架构**
   - Layer 1: 前端组件并行构建 (api,dashboard,libs)
   - Layer 2: 文档独立构建 (经常变更)
   - Layer 3: Go Runner独立构建 (最大组件)
   - Layer 4: 其他Go组件并行构建 (proxy,daemon,cli)

3. **⚡ 多阶段构建**
   - Builder阶段: 包含所有构建工具
   - Runtime阶段: 仅运行时依赖
   - 镜像大小最小化

详细的优化策略和最佳实践请查看: [OPTIMIZATION.md](./OPTIMIZATION.md)

## 📁 File Structure

```
docker/
├── README.md                     # This file
├── Dockerfile                    # Multi-stage optimized Dockerfile
├── docker-compose.yaml           # Standard development setup
├── docker-compose.build.yaml     # Optimized build setup
├── docker-compose.build-local.yaml # Local build setup
├── runner-entrypoint.sh          # Runner service entrypoint
├── build/
│   ├── README.md                 # Build tools documentation
│   ├── Makefile                  # Build automation with make
│   ├── build.sh                  # Standard build script
│   ├── build-optimized.sh        # Fast automated build script
│   ├── build.env.example         # Build environment variables
│   └── registry-login.sh         # Registry authentication
└── dex/
    └── config.yaml               # OIDC provider configuration
```

## 🛠️ Build Tools

### Makefile (推荐)

位于 `docker/build/` 目录的Makefile提供了最完整的构建选项：

- **快速构建**: `make build` - 构建所有服务
- **选择性构建**: `make build SERVICES=api,proxy` - 构建指定服务
- **清理资源**: `make clean` - 清理Docker资源
- **推送镜像**: `make build-push` - 构建并推送到注册表
- **查看帮助**: `make help` - 查看所有可用选项

### build-optimized.sh

快速优化构建脚本，专注于开发环境的快速迭代：

- 自动切换到项目根目录
- 启用BuildKit和并行构建
- 显示详细的性能分析和构建时间
- 构建时间目标: <40s (通常35-38s)
- 无参数选项，直接开始构建

### build.sh

标准构建脚本，支持环境配置和灵活选项：

- 支持环境变量配置文件
- 可配置的服务选择和平台支持
- 详细的构建日志和错误处理
- 支持本地和生产环境构建

使用示例：

```bash
# 快速构建 (推荐)
cd docker/build && make build

# 使用优化脚本
./docker/build/build-optimized.sh

# 使用标准脚本
./docker/build/build.sh

# 构建特定服务
cd docker/build && make build SERVICES=api

# 查看帮助
cd docker/build && make help
```

## 🔧 Troubleshooting

### Build Issues

- **Go module downloads slow**: Set `GOPROXY=https://goproxy.cn,direct` (for China users)
- **Yarn cache issues**: Clear with `yarn cache clean`
- **Build cache issues**: Reset with `docker builder prune -af`

### Service Access Issues

- **OIDC authentication fails**: Check dex service logs and issuer URLs
- **Services not responding**: Verify all services are healthy with `docker-compose ps`
- **Port conflicts**: Ensure ports 3000, 5050, 5100, 9001 are available
