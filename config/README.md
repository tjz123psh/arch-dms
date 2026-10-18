# config/ — deployable payload

This is the operator's personal configuration payload, not a generic dotfile
template. Only the files listed in `manifests/config-mappings.tsv` are copied
into the target HOME.

- `config/home/` — user files. Target paths are HOME-relative and the mode
  comes from the mapping row, not from the working-tree permission.
- `config/etc/` — system files deployed directly by the steps (greetd +
  nwg-hello, paru.conf, GRUB theme). They are not part of the mappings.
- `config/templates/` — manual reference copies (archlinuxcn/pacman hooks);
  the installer never reads them.
- Credentials, private profiles and caches are excluded; see
  `manifests/excluded.tsv`.
- Add a file: put it under `config/home/...`, run
  `./sync-config-mappings.sh <path>`, and commit both the file and the row.
