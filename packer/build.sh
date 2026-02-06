#!/bin/bash
# Build de l'image Claude-DevOps avec Packer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ISO_PATH="${1:-iso/ubuntu-24.04.3-live-server-amd64.iso}"

echo "=== Vérification des prérequis ==="

# Vérifier Packer
if ! command -v packer &> /dev/null; then
    echo "Packer n'est pas installé. Lancez d'abord : ../bin/install-packer"
    exit 1
fi

# Vérifier QEMU/KVM
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "QEMU n'est pas installé. Lancez d'abord : ../bin/install-packer"
    exit 1
fi

# Vérifier accès KVM
if [ ! -w /dev/kvm ]; then
    echo "Pas d'accès à /dev/kvm. Lancez d'abord : ../bin/install-packer"
    exit 1
fi

# Vérifier que l'ISO existe
if [ ! -f "$ISO_PATH" ]; then
    echo "ISO introuvable : $ISO_PATH"
    echo "Placez l'ISO Ubuntu 24.04 dans packer/iso/ ou passez le chemin en argument :"
    echo "  ./build.sh /chemin/vers/ubuntu-24.04.3-live-server-amd64.iso"
    exit 1
fi

echo "[OK] Packer: $(packer --version)"
echo "[OK] QEMU: disponible"
echo "[OK] KVM: accessible"
echo "[OK] ISO: $ISO_PATH"

echo ""
echo "=== Initialisation Packer ==="
packer init claude-devops.pkr.hcl

echo "=== Validation de la configuration ==="
packer validate -var "iso_path=$ISO_PATH" claude-devops.pkr.hcl

echo "=== Build de l'image ==="
PACKER_LOG=1 packer build -var "iso_path=$ISO_PATH" claude-devops.pkr.hcl

echo ""
echo "=== Build terminé ==="
echo "Image générée : output-claude-devops/claude-devops.qcow2"
echo ""
echo "Pour importer dans virt-manager :"
echo "  sudo cp output-claude-devops/claude-devops.qcow2 /var/lib/libvirt/images/"
echo "  sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/claude-devops.qcow2"
echo "  Puis : Fichier > Nouvelle VM > Importer une image disque existante"
