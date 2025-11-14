# BananaPro NAS Image Builder

## Automated Builds

The repository uses GitHub Actions to automatically build and release BananaPro images when changes are pushed to the `main` branch.

### How it works:
1. **Conventional Commits**: Use conventional commit messages (`feat:`, `fix:`, `docs:`, etc.) in your commits
2. **Automatic Versioning**: The CI pipeline uses semantic versioning to determine the next version based on your commits
3. **Automated Release**: Each push to `main` triggers a build that creates a GitHub release with the generated image

### Available Releases
Check the [Releases](https://github.com/rubeniskov/nas/releases) page for the latest BananaPro images.

### Commit Message Format
To ensure proper versioning, use conventional commit messages:
- `feat:` - New feature (triggers minor version bump)
- `fix:` - Bug fix (triggers patch version bump)
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `BREAKING CHANGE:` - Breaking changes (triggers major version bump)

## Manual Build

You can also build the image manually:

```bash
./scripts/banapro.sh build
```

This will:
- Build the mainline Banana Pro kernel (zImage, dtbs, modules, headers)
- Build U-Boot
- Create an Arch Linux ARM rootfs
- Generate the final `.img` file in `artifacts/banapro/`

### Build Commands:
- `./scripts/banapro.sh build` - Build everything (kernel, U-Boot, rootfs, and image)
- `./scripts/banapro.sh build-kernel` - Build only the kernel
- `./scripts/banapro.sh build-uboot` - Build only U-Boot
- `./scripts/banapro.sh build-rootfs` - Build only the rootfs
- `./scripts/banapro.sh build-image` - Build only the image (requires pre-built rootfs)

# References

- https://archlinuxarm.org/platforms/armv7/allwinner/cubietruck
- https://forum.armbian.com/topic/841-bananapro-lemaker-5in-lcd-legacy-kernel/
- https://github.com/LeMaker/fex_configuration/blob/master/README.md
- https://forum.armbian.com/topic/14560-sun4i-drm-and-lcd-panels/
- https://linux-sunxi.org/A20#DVFS
- https://software-dl.ti.com/processor-sdk-linux/esd/AM62X/09_01_00_08/exports/docs/linux/How_to_Guides/Target/How_to_enable_DT_overlays_in_linux.html
- https://github.com/wens/dt-overlays/tree/master
- https://xnux.eu/howtos/install-arch-linux-arm.html
- https://linux-sunxi.org/Manual_build_howto#Build_U-Boot
- https://linux-sunxi.org/Mainline_Kernel_Howto
- https://linux-sunxi.org/Possible_setups_for_hacking_on_mainline
- https://linux-sunxi.org/Device_Tree
