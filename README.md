# Claude-DevOps VM

Image VM Ubuntu 24.04 LTS (QCOW2) prête à l'emploi avec Docker, Claude Code CLI, git et SSH. Construite avec Packer, importable dans virt-manager.

## Logiciels inclus

- Ubuntu 24.04 LTS Server
- Docker CE (avec docker-compose plugin)
- Claude Code CLI
- Git, curl, vim, htop
- SSH (authentification par mot de passe)

## Prérequis

Installer Packer et les dépendances QEMU/KVM :

```bash
./bin/install-packer
```

## Build

1. Placer l'ISO Ubuntu 24.04.3 Server dans `packer/iso/` :

```bash
# Télécharger ou créer un lien symbolique
ln -s /chemin/vers/ubuntu-24.04.3-live-server-amd64.iso packer/iso/
```

2. Lancer le build :

```bash
cd packer
./build.sh
```

Ou avec un chemin ISO personnalisé :

```bash
cd packer
./build.sh /chemin/vers/ubuntu-24.04.3-live-server-amd64.iso
```

L'image sera générée dans `packer/output-claude-devops/claude-devops.qcow2`.

## Import dans virt-manager

```bash
sudo cp packer/output-claude-devops/claude-devops.qcow2 /var/lib/libvirt/images/
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/claude-devops.qcow2
```

Dans virt-manager :
1. Fichier > Nouvelle machine virtuelle
2. Importer une image disque existante
3. Sélectionner `/var/lib/libvirt/images/claude-devops.qcow2`
4. OS : Ubuntu 24.04, RAM : 4096 MB, CPU : 2 cores

## Credentials

- **User :** `claude`
- **Password :** `password`
- **SSH :** `ssh claude@<IP_VM>`

## Mount a host directory in VM

Make sure to have `virtiofs` installed on the host :

`sudo apt-get install virtiofsd`

In the newly created VM (stopped) :

- in the memory section enable "Enable shared memory"
- add a virtual hardware/filesystem
- choose virtiofs, locate the source path, give a name to the label on the VM (target path is not a path it's a LABEL)

In the VM run something like :

```sh
mkdir /path/to/host_directory
sudo mount -t virtiofs LABEL /path/to/host_directory
```

## Structure

```
claude_vm/
├── .gitignore
├── README.md
├── bin/
│   └── install-packer        # Installation des prérequis
└── packer/
    ├── build.sh               # Lance le build Packer
    ├── claude-devops.pkr.hcl  # Configuration Packer
    ├── iso/                   # Placer l'ISO Ubuntu ici
    │   └── .gitkeep
    └── http/
        ├── user-data          # Autoinstall config
        └── meta-data
```
