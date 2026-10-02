# Debian 6.18 LTS Kernel Project

A streamlined build and packaging pipeline targeting **Debian 13 (Trixie)** to track, compile, and distribute the **upstream Linux 6.18 LTS** kernel series with official Debian configuration standards.

---

## 1. Motivation

* **Debian 13 Stock Kernel (`6.12.y`):** Conservative and fully frozen, but lacks modern hardware support, newer filesystem improvements (e.g., bcachefs), and recent BPF/scheduler enhancements.
* **Debian Backports (`trixie-backports`):** Tracks rolling mainline (`7.x`), which has short ~9-week upstream lifecycles. Backports frequently lag, leaving systems on upstream EOL kernels with zero security support until major version bumps.
* **This Project (`6.18.y LTS`):** Provides a continuous, stable stream tracking Greg K-H's upstream LTS releases without the constant ABI breaks and DKMS failures of rolling kernels.

---

## 2. Project Structure

```
debian-lts/
├── Makefile                      # Top-level orchestration
├── config/                       # Baseline configurations from Debian Kernel Team
│   ├── config.amd64_none_amd64   # Standard Debian modular desktop/server kernel
│   ├── config.amd64_none_cloud-amd64 # Lightweight cloud VM kernel
│   └── config.amd64_none_rt-amd64    # PREEMPT_RT deterministic kernel
├── scripts/
│   ├── setup-env.sh              # Host build dependency checks and installer
│   ├── fetch-kernel.sh           # Shallow or tag-specific git fetcher
│   ├── prepare-config.sh         # Reconciles baseline config with upstream Kconfig
│   ├── build.sh                  # Invokes make bindeb-pkg and job control
│   ├── build-metapackage.sh      # Builds rolling linux-image-6.18-lts-amd64 metapackages
│   ├── podman-build.sh           # Container build runner
│   └── check-upstream.sh         # Checks kernel.org for new LTS point releases
├── Containerfile                 # Isolated Debian 13 build environment
└── dist/                         # Generated Debian .deb packages (git-ignored)
```

---

## 3. Quickstart

### Prerequisites

Run dependency verification:
```bash
make setup
```
Required packages: `build-essential bc bison flex libelf-dev libdw-dev libssl-dev dwarves kmod rsync cpio fakeroot zstd libncurses-dev git debhelper sbsigntool`.

### Containerized Build (Recommended: Zero Host Pollution)

To build inside a clean, isolated Debian 13 container using **Podman** without installing build tools or compilers on the host:
```bash
# Build kernel inside Podman container (creates .deb packages in dist/)
make container-build

# Or launch an interactive shell in the container
make container-shell
```

### Host Build Workflow


1. **Fetch upstream kernel sources:**
   ```bash
   make fetch
   ```
   *(Defaults to `git.kernel.org` branch `linux-6.18.y`)*

2. **Prepare configuration:**
   ```bash
   make config
   ```
   *(Applies Debian's official `config.amd64_none_amd64` baseline and resolves new symbols with `make olddefconfig`)*

3. **(Optional) Customize kernel configuration:**
   ```bash
   make menuconfig
   ```

4. **Compile and generate Debian packages:**
   ```bash
   make build
   ```

Outputs will be placed in `dist/`:
* `linux-image-6.18.X-lts_6.18.X-1~deb13_amd64.deb`
* `linux-headers-6.18.X-lts_6.18.X-1~deb13_amd64.deb`
* `linux-libc-dev_6.18.X-1~deb13_amd64.deb`
* `linux-image-6.18-lts-amd64_6.18.X-lts-1~deb13_amd64.deb` (metapackage)
* `linux-headers-6.18-lts-amd64_6.18.X-lts-1~deb13_amd64.deb` (metapackage)

---

## 4. Configuration Details

Baseline configs in `config/` are extracted directly from Debian's official `linux-config-6.18` package.

Key settings maintained:
* **Preemption:** `CONFIG_PREEMPT_DYNAMIC=y` (allows runtime selection via `preempt=` cmdline).
* **BTF & eBPF:** `CONFIG_DEBUG_INFO_BTF=y` and `CONFIG_DEBUG_INFO_BTF_MODULES=y` enabled via Debian `dwarves` (pahole 1.30).
* **Security:** `CONFIG_SECURITY_APPARMOR=y`, `CONFIG_SECURITY_LOCKDOWN_LSM=y`.
* **Signing:** Debian internal signing keys are cleared so builds succeed without private Debian keys.

### Build Optimization
By default, `scripts/prepare-config.sh` disables uncompressed DWARF debug info (`CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=n`) while **retaining BTF**. This reduces build times by ~80% and disk space usage from ~35 GB down to ~3 GB. To build full debug symbols, export `FULL_DEBUG=1`.

---

## 5. UEFI Secure Boot & MOK Signing

To boot the resulting kernel with UEFI Secure Boot enabled:

1. **Generate a MOK key pair:**
   ```bash
   openssl req -new -x509 -newkey rsa:2048 -nodes -days 3650 \
     -subj "/CN=Debian LTS Kernel MOK/" \
     -keyout certs/mok.key -out certs/mok.crt
   ```
2. **Re-run `make config && make build`:**
   The build scripts automatically detect `certs/mok.key` and embed the certificate into `CONFIG_SYSTEM_TRUSTED_KEYS` and sign all compiled `.ko` modules.
3. **Enroll key on target machine:**
   ```bash
   sudo mokutil --import certs/mok.crt
   # Enter a one-time password and reboot to complete MOK enrollment in UEFI BIOS.
   ```

---

## 6. APT Distribution (reprepro)

To distribute builds to multiple machines:

```bash
sudo apt-get install -y reprepro

# Add packages to local repository
reprepro -b /var/www/repos/debian includedeb trixie dist/*.deb
```

Target machines simply configure the repository and install the rolling metapackage:
```bash
sudo apt-get install linux-image-6.18-lts-amd64 linux-headers-6.18-lts-amd64
```
Subsequent builds will upgrade smoothly via `apt upgrade`.
