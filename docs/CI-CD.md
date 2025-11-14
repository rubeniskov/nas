# CI/CD Pipeline Documentation

## Overview

This repository uses GitHub Actions to automatically build and release BananaPro images based on conventional commits.

## Workflow: Build and Release BananaPro Image

**File**: `.github/workflows/build-release.yml`

### Trigger
- Runs on every push to the `main` branch

### Process

1. **Version Determination**
   - Uses `semantic-release` to analyze commit messages
   - Determines next version based on conventional commit format
   - Skips build if no version change is needed

2. **Build Process** (only if new version is detected)
   - Clones necessary repositories (Linux kernel, U-Boot, dt-overlays)
   - Applies patches
   - Builds Linux kernel and device tree overlays
   - Builds U-Boot bootloader
   - Creates Arch Linux ARM rootfs
   - Generates bootable SD card image (.img)
   - Compresses image to .img.tgz

3. **Release Creation**
   - Creates GitHub release with the new version tag
   - Uploads built artifacts:
     - `archlinuxarm-bananapro-{version}.img` - Bootable SD card image
     - `archlinuxarm-bananapro-{version}.img.tgz` - Compressed image
     - `checksums.txt` - SHA256 checksums for verification
   - Generates changelog from commit messages
   - Commits changelog back to repository

## Conventional Commit Format

The workflow uses conventional commits to determine version bumps:

- `feat:` - New feature → Minor version bump (e.g., 1.0.0 → 1.1.0)
- `fix:` - Bug fix → Patch version bump (e.g., 1.0.0 → 1.0.1)
- `BREAKING CHANGE:` - Breaking change → Major version bump (e.g., 1.0.0 → 2.0.0)
- `docs:`, `chore:`, `style:`, `refactor:`, `test:` - No version bump

### Examples

```bash
# Feature addition (minor bump)
git commit -m "feat: add LCD overlay support"

# Bug fix (patch bump)
git commit -m "fix: correct kernel boot parameters"

# Breaking change (major bump)
git commit -m "feat: update to newer kernel version

BREAKING CHANGE: requires new device tree format"

# No version bump
git commit -m "docs: update README with build instructions"
```

## Optimizations

The workflow includes several optimizations:

1. **Repository Caching**
   - Caches cloned repositories (linux, u-boot, dt-overlays)
   - Speeds up subsequent builds significantly

2. **Disk Space Management**
   - Removes unnecessary files before build
   - Ensures enough space for kernel compilation

3. **Build Logging**
   - Captures complete build output
   - Uploads logs as artifacts for debugging

4. **Timeout Protection**
   - 5-hour timeout prevents stuck builds
   - Ensures CI resources are not wasted

## Build Artifacts

After a successful build, the following artifacts are available:

### GitHub Release Assets
- BananaPro Image (.img) - ~2GB bootable SD card image
- BananaPro Image (.img.tgz) - Compressed version
- checksums.txt - SHA256 checksums for verification
- CHANGELOG.md - Automatically generated changelog

### Build Artifacts (available for 7 days)
- build.log - Complete build output

## Using Released Images

1. Download the latest `.img.tgz` from the [Releases](https://github.com/rubeniskov/nas/releases) page
2. Extract: `tar -xzf archlinuxarm-bananapro-{version}.img.tgz`
3. Verify checksum: `sha256sum -c checksums.txt`
4. Write to SD card: `sudo dd if=archlinuxarm-bananapro-{version}.img of=/dev/sdX bs=4M status=progress`
5. Sync: `sudo sync`

Replace `/dev/sdX` with your SD card device.

## Troubleshooting

### Build Failures

If a build fails:
1. Check the build log artifact in the workflow run
2. Review the commit messages - ensure they follow conventional format
3. Check disk space and build timeout settings

### No Release Created

If commits are pushed but no release is created:
- Check that commits follow conventional format
- Only `feat:`, `fix:`, or `BREAKING CHANGE:` trigger releases
- Review the "Determine next version" step output

### Manual Trigger

To manually build without pushing to main:
```bash
# Clone the repository
git clone https://github.com/rubeniskov/nas.git
cd nas

# Run the build script
./scripts/banapro.sh build

# Find the generated image
ls -lh artifacts/banapro/archlinuxarm-bananapro.img
```

## Maintenance

### Updating Dependencies

To update kernel, U-Boot, or dt-overlays versions:
1. Edit `scripts/banapro/common.sh`
2. Update `LINUX_REV`, `UBOOT_REV`, or `DTO_REV` variables
3. Commit with appropriate conventional commit message
4. Push to main - new image will be built automatically

### Modifying Build Process

The build process is controlled by:
- `scripts/banapro.sh` - Main build orchestration
- `scripts/banapro/kernel.sh` - Kernel build logic
- `scripts/banapro/uboot.sh` - U-Boot build logic
- `scripts/banapro/rootfs.sh` - Rootfs creation
- `scripts/banapro/image.sh` - Image assembly

Any changes to these scripts should be tested locally first.
