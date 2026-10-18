# Review: vmware-workstation

## Status

- Decision: **reviewed AUR recipe; physical/VMware-host only** (module
  `virtualization-vmware-host`, selected exclusively when
  `MACHINE_TYPE=physical`). Never installed on the vm/VMware-guest branch.
- Large vendor payload: the source is a ~1.1 GiB Workstation bundle plus
  multiple VMware Tools ISOs fetched at build time from archive.org /
  packages-prod.broadcom.com. The recipe files (PKGBUILD, services, patches,
  bootstrap scripts) are committed to the repo; the bundle/ISO payloads are
  NOT committed and are downloaded + hash-verified by `makepkg` during the
  build (standard AUR flow), so the build needs network access and disk space
  for the bundle and the Tools ISOs.

## Provenance

- AUR origin: `https://aur.archlinux.org/vmware-workstation.git`
- AUR commit: `ff1d37c27b6d935b63cac9682276271af6cc9f3a`
- Version: `26H1-3` (build 25388281); license: custom (Broadcom EULA).
- Bundle source SHA-256 (first source): `3f6d2501e654dbc7701a8290ff6ffcfba6c5444cd5f35f4933cd08c9499f6d84`
- Critical AUR→AUR edge: `depends+=(vmware-keymaps)` — vmware-keymaps must be
  built and installed BEFORE vmware-workstation's `makepkg -s` runs, otherwise
  dependency resolution fails.

## Build flow (as integrated)

- 06-aur.sh builds vmware-keymaps first (bootstrap), installs it with a
  dedicated `pacman -U`, then proceeds with the main batch (including
  vmware-workstation). This resolves the AUR→AUR edge that the old
  "build-all-then-install-all" model could not.
- DKMS: the package builds only the `vmmon` and `vmnet` modules (its
  dkms.conf lists exactly those two). There is no `vmci` module — guests must
  set `vmci0.present = "FALSE"` in their VMX (documented in the VMware ops
  notes; the project never edits real VMX files).
- Host services enabled by 08-services.sh (physical only):
  `vmware-networks.service` and `vmware-usbarbitrator.service`.
  `vmware-networks-configuration.service` is static (oneshot) and is NOT
  enabled; there is no `vmware-vmnet.service` unit.

## Known limitations (from host ops notes, 2026-08-07)

- `vmware-modconfig --console --install-all` is NOT usable on this host
  (AppLoader GLib/GSettings error, no vmware.service); module management is
  done via DKMS + `modprobe vmmon vmnet`.
- Linux UI is English-only (no translation files ship in the package).
