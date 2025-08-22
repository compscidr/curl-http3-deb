# curl-http3-deb

curl-http3-deb creates .deb packages for curl with HTTP/3 and QUIC support for Ubuntu 22.04/24.04. It packages the build instructions from curl.se/docs/http3.html into installable .deb packages and distributes them via Docker Hub and a custom apt repository.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Docker Build Process
- Multi-stage Docker build with stages: `prereqs` -> `build` -> `curl` -> `deploy`
- **NEVER CANCEL builds** - compilation takes 45+ minutes. ALWAYS set timeouts to 60+ minutes minimum.
- Build process:
  1. `prereqs` stage: Install build tools (takes ~37 seconds)
  2. `build` stage: Compile OpenSSL, nghttp3, ngtcp2, curl from source (takes 45+ minutes total)
  3. `curl` stage: Create runtime Docker image with compiled curl
  4. `deploy` stage: Publish .deb packages to Gemfury apt repository

### Build Commands and Timing
- `docker build --target prereqs -t curl-prereqs .` -- takes 37 seconds
- `docker build --target build -t curl-build .` -- takes 45+ minutes. NEVER CANCEL. Set timeout to 60+ minutes.
- `docker build --target curl -t curl-final .` -- takes 45+ minutes. NEVER CANCEL. Set timeout to 60+ minutes.
- `docker build .` -- full build takes 45+ minutes. NEVER CANCEL. Set timeout to 60+ minutes.

### Network Dependencies
- **CRITICAL**: Build process requires network access to clone from GitHub:
  - `https://github.com/quictls/openssl` (OpenSSL with QUIC support)
  - `https://github.com/ngtcp2/nghttp3` (HTTP/3 library)
  - `https://github.com/ngtcp2/ngtcp2` (QUIC library)
  - `https://github.com/curl/curl` (curl source)

### Testing and Validation
- **Use Pre-built Image**: `docker run --rm compscidr/curl-http3-quic --version`
  - Should show: `curl 8.4.1-DEV` with `HTTP3` and `ngtcp2/1.0.0 nghttp3/1.1.0-DEV` features
- **Basic functionality**: `docker run --rm compscidr/curl-http3-quic --help`
- **Smoke Test Workflow**: Use `.github/workflows/smoke-test.yml` for comprehensive build validation
  - Builds from source and tests HTTP3/QUIC functionality
  - Manually trigger with GitHub Actions workflow_dispatch for testing changes
  - Faster validation than full deploy pipeline (no publishing steps)
- **ALWAYS validate any changes by running**: 
  - `docker run --rm compscidr/curl-http3-quic --version | grep HTTP3`
  - Verify HTTP3 support is present in the feature list

### CI/CD Pipeline
**Deploy Workflow (.github/workflows/deploy.yml)**:
- Triggers on pushes to `main` branch (excluding README.md changes)
- Requires secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_PASSWORD`, `GFKEY_PUSH`
- **Build timing**: Full CI build takes 45+ minutes. Do not cancel GitHub Actions runs.

**Smoke Test Workflow (.github/workflows/smoke-test.yml)**:
- Triggers on all pushes and pull requests for early build validation
- Builds Docker image to `curl` target (skips deploy stage)
- No secrets required, doesn't publish packages
- **Build timing**: ~45+ minutes (builds OpenSSL, nghttp3, ngtcp2, curl from source)
- Tests basic curl functionality with HTTP3/QUIC support verification
- **Use for validation**: Manually trigger with workflow_dispatch for testing changes

## Validation Scenarios

### After Making Changes
1. **ALWAYS test basic functionality first**:
   ```bash
   docker run --rm compscidr/curl-http3-quic --version
   docker run --rm compscidr/curl-http3-quic --help | head -10
   ```

2. **Verify HTTP/3 support is present**:
   ```bash
   docker run --rm compscidr/curl-http3-quic --version | grep -i http3
   docker run --rm compscidr/curl-http3-quic --version | grep ngtcp2
   ```

3. **For comprehensive validation, use smoke test workflow**:
   - Manually trigger `.github/workflows/smoke-test.yml` via GitHub Actions
   - Builds from source and validates HTTP3/QUIC functionality
   - Validates build process without requiring local compilation

4. **If modifying Dockerfile, test build stages locally**:
   - Test prereqs stage: `docker build --target prereqs .` (timeout: 300s)
   - **Full build requires network access**: `docker build --target build .` (timeout: 3600s)

### Build Environment Requirements
- Docker must be available
- Network access to github.com for source repository cloning
- Sufficient disk space for multi-stage build (several GB)
- **Minimum 60+ minutes timeout** for any build command beyond prereqs stage

## Common Tasks

### Repository Structure
```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml          # CI/CD pipeline
│       └── smoke-test.yml      # Build validation workflow
├── .gitignore                  # Excludes .idea
├── Dockerfile                  # Multi-stage build definition
├── README.md                   # Usage and installation docs
└── renovate.json              # Dependency update configuration
```

### Key Files Contents

#### Dockerfile Overview
- `FROM ubuntu:24.04 as prereqs`: Install build dependencies
- `FROM prereqs as build`: Compile OpenSSL → nghttp3 → ngtcp2 → curl
- `FROM ubuntu:24.04 as curl`: Runtime image with compiled curl
- `FROM ubuntu:24.04 as deploy`: Package publishing stage

#### Package Installation (from README.md)
Users can install packages by adding to `/etc/apt/sources.list.d/compscidr.list`:
```
deb [trusted=yes] https://apt.fury.io/compscidr/ /
```

Then run:
```bash
sudo apt update && sudo apt install \
    openssl=3.0.0+quic-jammy-1 \
    nghttp3=0.7.0-4-g8597ab3-jammy-1 \
    ngtcp2=0.9.0-14-gccb745e5-jammy-1 \
    curl=7-85-0-177-g0a652280c-jammy-1
```

### Troubleshooting
- **If build takes longer than expected**: This is normal - each compilation step is time-intensive
- **If CI builds fail**: Check network connectivity and GitHub repository availability

### Dependencies and Updates
- **Renovate**: Automated dependency updates via renovate.json
- **Source versions**: Currently uses latest from upstream git repositories (not pinned)
- **TODO items** (from README.md):
  - Rename package to avoid conflicts with official curl package
  - Rename curl binary to avoid conflicts  
  - Pin git repositories to tagged releases instead of latest

## Development Workflow
1. **ALWAYS start with pre-built image testing** to verify expected behavior
2. Make minimal changes to Dockerfile if needed
3. Test prereqs stage first (quick validation)
4. **Build from source** for full validation
5. Use smoke test workflow for comprehensive validation
6. **NEVER cancel long-running builds** - they are expected to take 45+ minutes