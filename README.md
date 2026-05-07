# proxmox-renumber
Script Bash pour renuméroter automatiquement des VM QEMU et containers LXC sous Proxmox VE.
Le script gère :
- renommage des fichiers de configuration
- renommage des références de disques
- stockage directory
- LVM / LVM-Thin
- ZFS
- VM QEMU
- Containers LXC
# ⚠️ Avertissement
Ce script modifie directement les configurations Proxmox.
Avant utilisation :
- faire un backup
- arrêter la VM/LXC
- tester dans un environnement de lab
Utilisation à vos risques.

# Fonctionnalités
✅ Renommage automatique des VMID / CTID  
✅ Compatible VM et LXC  
✅ Sauvegarde automatique des configs  
✅ Gestion :
- Directory Storage
- LVM
- LVM-Thin
- ZFS

✅ Mise à jour automatique des références :
- `vm-OLD-disk-X`
- `subvol-OLD-disk-X`
- `/images/OLD/`
---

# Compatibilité

Testé sur :

- Proxmox VE 9.1.9
- Debian 13

---

# Installation

Cloner le dépôt :

```bash
git clone https://github.com/USER/proxmox-renumber.git
cd proxmox-renumber
```

Rendre le script exécutable :

```bash
chmod +x proxmox-renumber.sh
```

---

# Utilisation

## Renommer une VM

```bash
./proxmox-renumber.sh vm OLDID NEWID
```

Exemple :

```bash
./proxmox-renumber.sh vm 100 200
```

---

## Renommer un container LXC

```bash
./proxmox-renumber.sh lxc OLDID NEWID
```

Exemple :

```bash
./proxmox-renumber.sh lxc 101 201
```

---

# Exemples

## VM

Avant :

```text
100.conf
vm-100-disk-0
```

Après :

```text
200.conf
vm-200-disk-0
```

---

## LXC

Avant :

```text
101.conf
subvol-101-disk-0
```

Après :

```text
201.conf
subvol-201-disk-0
```

---

# Sauvegarde recommandée
---
# Vérifications utiles
Lister les VM :
```bash
qm list
```
Lister les CT :
```bash
pct list
```
Lister les volumes LVM :
```bash
lvs
```
Lister les datasets ZFS :
```bash
zfs list
```
---
# Limitations
Le script ne gère pas automatiquement :
- Ceph RBD avancé
- Clusters complexes multi-storage exotiques
- Snapshots externes
- Réplication Proxmox
- Backups PBS liés au VMID
---
# Bonnes pratiques
- Toujours arrêter la VM/LXC
- Toujours faire un backup
- Vérifier les disques orphelins
- Tester dans un homelab avant production
---
# Licence
GNU General Public License v3.0
---
# Auteur
Créé pour la communauté Proxmox ❤️
