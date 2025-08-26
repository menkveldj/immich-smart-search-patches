# Automated Build Setup Guide

This guide will help you set up automated builds that monitor Immich releases, apply patches, and publish Docker images.

## 🚀 Quick Start

### Prerequisites
- GitHub repository with Actions enabled
- GitHub Container Registry (GHCR) access (comes with your GitHub account)

### Step 1: Enable GitHub Actions

1. Go to your repository: https://github.com/menkveldj/immich-smart-search-patches
2. Click on **Actions** tab
3. Enable workflows if not already enabled

### Step 2: Configure Permissions

1. Go to **Settings** → **Actions** → **General**
2. Under "Workflow permissions", select:
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests

### Step 3: Set Up Container Registry

GitHub Container Registry (GHCR) is automatically available. The workflow will publish to:
```
ghcr.io/menkveldj/immich-server-patched
```

## 📅 Automated Daily Builds

The workflow runs automatically every day at 2 AM UTC and will:

1. **Check** for new Immich releases
2. **Clone** the latest Immich source
3. **Apply** your patches
4. **Build** multi-architecture Docker images (amd64, arm64)
5. **Test** that patches were applied correctly
6. **Push** to GitHub Container Registry
7. **Create** a GitHub release with notes

### Monitoring Builds

Check build status:
- Go to **Actions** tab
- Look for "Check Immich Releases and Build" workflow
- Green ✅ = successful build
- Red ❌ = build failed (you'll get an issue created)

## 🔧 Manual Builds

You can manually trigger a build:

1. Go to **Actions** tab
2. Click "Manual Build and Push"
3. Click "Run workflow"
4. Enter Immich version (e.g., `v1.122.3`)
5. Click "Run workflow"

## 🐳 Using the Docker Images

### In Docker Compose

```yaml
version: '3.8'

services:
  immich-server:
    image: ghcr.io/menkveldj/immich-server-patched:latest
    # Or use a specific version:
    # image: ghcr.io/menkveldj/immich-server-patched:v1.122.3
    container_name: immich_server
    # ... rest of your Immich server configuration
```

### Pull Manually

```bash
# Latest version
docker pull ghcr.io/menkveldj/immich-server-patched:latest

# Specific version
docker pull ghcr.io/menkveldj/immich-server-patched:v1.122.3
```

### Authentication (if repo is private)

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

## 🔍 Testing Patches Locally

Before committing changes, test your patches:

```bash
# Make the script executable
chmod +x scripts/validate-patch.sh

# Test against a specific version
./scripts/validate-patch.sh v1.122.3

# Test against latest
./scripts/validate-patch.sh
```

## 🚨 Handling Build Failures

If a build fails (patches don't apply cleanly):

1. **Check the issue** created automatically in your repo
2. **Clone the new Immich version locally**:
   ```bash
   git clone --branch vX.X.X https://github.com/immich-app/immich.git
   ```

3. **Try applying patches**:
   ```bash
   cd immich
   git apply ../patches/add-smartsearch-score-and-album.diff
   ```

4. **Fix conflicts** and update the patch:
   ```bash
   # Make necessary code changes
   git add -A
   git diff --staged > ../patches/add-smartsearch-score-and-album.diff
   ```

5. **Commit and push** the updated patch
6. **Manually trigger** a rebuild

## 📊 Monitoring and Notifications

### Build Status Badge

Add to your README:
```markdown
![Build Status](https://github.com/menkveldj/immich-smart-search-patches/actions/workflows/check-and-build.yml/badge.svg)
```

### Email Notifications

GitHub will email you when:
- Builds fail
- Issues are created
- Releases are published

Configure in: Settings → Notifications

## 🔐 Security Best Practices

1. **Keep patches minimal** - Easier to maintain
2. **Review Immich changes** - Check release notes
3. **Test before production** - Use the test scripts
4. **Monitor for CVEs** - Enable Dependabot

## 📋 Maintenance Checklist

Weekly:
- [ ] Check Actions tab for any failed builds
- [ ] Review open issues
- [ ] Check if manual intervention needed

Monthly:
- [ ] Review patch compatibility
- [ ] Update documentation if needed
- [ ] Clean up old Docker images

## 🆘 Troubleshooting

### Build fails immediately
- Check if Immich changed their Dockerfile location
- Verify patch file exists and is valid

### Patches don't apply
- Run `validate-patch.sh` locally
- Update patches for new code structure
- Check Immich's changelog for breaking changes

### Docker push fails
- Check GitHub token permissions
- Ensure workflow has write access
- Verify registry quota not exceeded

### Multi-arch build is slow
- Normal - building for multiple architectures takes time
- Consider building only amd64 if arm64 not needed

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Immich Releases](https://github.com/immich-app/immich/releases)
- [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/)

## 💡 Tips

1. **Version Pinning**: Use specific versions in production
2. **Backup**: Always backup before updating Immich
3. **Test Environment**: Run a test instance first
4. **Stay Informed**: Watch Immich repo for breaking changes

---

Need help? Open an issue in the repository!