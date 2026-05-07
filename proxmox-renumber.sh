#!/usr/bin/env bash
set -euo pipefail

# proxmox-renumber.sh
# Usage:
#   ./proxmox-renumber.sh vm  OLDID NEWID
#   ./proxmox-renumber.sh lxc OLDID NEWID
#
# Exemple:
#   ./proxmox-renumber.sh vm 101 201
#   ./proxmox-renumber.sh lxc 102 202
TYPE="${1:-}"
OLD="${2:-}"
NEW="${3:-}"
BACKUP_DIR="/root/proxmox-renumber-backup-$(date +%Y%m%d-%H%M%S)"
die() {
  echo "ERREUR: $*" >&2
  exit 1
}
need_root() {
  [[ "$EUID" -eq 0 ]] || die "lance le script en root"
}
check_args() {
  [[ "$TYPE" =~ ^(vm|lxc)$ ]] || die "type invalide: vm ou lxc"
  [[ "$OLD" =~ ^[0-9]+$ ]] || die "OLDID doit être numérique"
  [[ "$NEW" =~ ^[0-9]+$ ]] || die "NEWID doit être numérique"
  [[ "$OLD" != "$NEW" ]] || die "OLDID et NEWID identiques"
}
is_running() {
  if [[ "$TYPE" == "vm" ]]; then
    qm status "$OLD" | grep -q "status: running"
  else
    pct status "$OLD" | grep -q "status: running"
  fi
}
config_path() {
  if [[ "$TYPE" == "vm" ]]; then
    echo "/etc/pve/qemu-server/${OLD}.conf"
  else
    echo "/etc/pve/lxc/${OLD}.conf"
  fi
}
new_config_path() {
  if [[ "$TYPE" == "vm" ]]; then
    echo "/etc/pve/qemu-server/${NEW}.conf"
  else
    echo "/etc/pve/lxc/${NEW}.conf"
  fi
}
rename_directory_storage() {
  # Renomme les dossiers classiques type:
  # /var/lib/vz/images/OLD -> /var/lib/vz/images/NEW
  # /mnt/pve/<storage>/images/OLD -> /mnt/pve/<storage>/images/NEW
  local paths=(
    "/var/lib/vz/images"
    /mnt/pve/*/images
  )
  for base in "${paths[@]}"; do
    [[ -d "$base/$OLD" ]] || continue
    [[ ! -e "$base/$NEW" ]] || die "$base/$NEW existe déjà"
    echo "Renommage dossier: $base/$OLD -> $base/$NEW"
    mv "$base/$OLD" "$base/$NEW"
    echo "Renommage fichiers dans $base/$NEW"
    find "$base/$NEW" -depth -name "*-${OLD}-*" | while read -r f; do
      nf="$(echo "$f" | sed "s/-${OLD}-/-${NEW}-/g")"
      echo "  $f -> $nf"
      mv "$f" "$nf"
    done
  done
}
rename_lvm_volumes() {
  # Renomme volumes LVM/LVM-thin si présents:
  # vm-OLD-disk-X -> vm-NEW-disk-X
  # subvol-OLD-disk-X -> subvol-NEW-disk-X
  command -v lvs >/dev/null 2>&1 || return 0
  command -v lvrename >/dev/null 2>&1 || return 0
  lvs --noheadings -o vg_name,lv_name | while read -r vg lv; do
    if [[ "$lv" =~ ^vm-${OLD}- ]] || [[ "$lv" =~ ^subvol-${OLD}- ]]; then
      new_lv="${lv//$OLD/$NEW}"
      echo "Renommage LV: $vg/$lv -> $vg/$new_lv"
      lvrename "$vg" "$lv" "$new_lv"
    fi
  done
}
rename_zfs_datasets() {
  # Renomme datasets/volumes ZFS si zfs est disponible:
  # pool/.../vm-OLD-disk-X -> pool/.../vm-NEW-disk-X
  # pool/.../subvol-OLD-disk-X -> pool/.../subvol-NEW-disk-X
  command -v zfs >/dev/null 2>&1 || return 0
  zfs list -H -o name | grep -E "(vm-${OLD}-|subvol-${OLD}-)" | while read -r ds; do
    new_ds="$(echo "$ds" | sed "s/vm-${OLD}-/vm-${NEW}-/g; s/subvol-${OLD}-/subvol-${NEW}-/g")"
    echo "Renommage ZFS: $ds -> $new_ds"
    zfs rename "$ds" "$new_ds"
  done
}
update_config_references() {
  local cfg
  cfg="$(new_config_path)"

  echo "Mise à jour références dans $cfg"

  sed -i \
    -e "s/vm-${OLD}-/vm-${NEW}-/g" \
    -e "s/subvol-${OLD}-/subvol-${NEW}-/g" \
    -e "s#/images/${OLD}/#/images/${NEW}/#g" \
    "$cfg"
}
main() {
  need_root
  check_args
  local old_cfg new_cfg
  old_cfg="$(config_path)"
  new_cfg="$(new_config_path)"

  [[ -f "$old_cfg" ]] || die "config introuvable: $old_cfg"
  [[ ! -e "$new_cfg" ]] || die "la destination existe déjà: $new_cfg"

  if is_running; then
    die "$TYPE $OLD est en cours d'exécution. Arrête-le avant."
  fi
  mkdir -p "$BACKUP_DIR"
  cp -a "$old_cfg" "$BACKUP_DIR/"
  echo "Backup config: $BACKUP_DIR"
  echo "Renommage config: $old_cfg -> $new_cfg"
  mv "$old_cfg" "$new_cfg"
  rename_directory_storage
  rename_lvm_volumes
  rename_zfs_datasets
  update_config_references
  echo
  echo "Terminé."
  echo "Vérification:"
  if [[ "$TYPE" == "vm" ]]; then
    qm config "$NEW"
    echo "Démarrage: qm start $NEW"
  else
    pct config "$NEW"
    echo "Démarrage: pct start $NEW"
  fi
}
main
