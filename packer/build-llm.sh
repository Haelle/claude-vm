#!/bin/bash
# Build de l'image Local-LLM avec Packer (Docker, Podman, Ollama, Devstral, Mistral Vibe)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ISO_PATH="${1:-iso/ubuntu-24.04.3-live-server-amd64.iso}"

echo "=== Build Local-LLM VM ==="
echo ""

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
    echo "  ./build-llm.sh /chemin/vers/ubuntu-24.04.3-live-server-amd64.iso"
    exit 1
fi

echo "[OK] Packer: $(packer --version)"
echo "[OK] QEMU: disponible"
echo "[OK] KVM: accessible"
echo "[OK] ISO: $ISO_PATH"

echo ""
echo "=== Initialisation Packer ==="
packer init local-llm.pkr.hcl

echo "=== Validation de la configuration ==="
packer validate -var "iso_path=$ISO_PATH" local-llm.pkr.hcl

echo "=== Build de l'image (cela peut prendre du temps pour télécharger Devstral) ==="
PACKER_LOG=1 packer build -var "iso_path=$ISO_PATH" local-llm.pkr.hcl

echo ""
echo "=== Build terminé ==="
echo "Image générée : output-local-llm/local-llm.qcow2"
echo ""
echo "Configuration de la VM:"
echo "  - RAM: 16GB minimum recommandé"
echo "  - CPUs: 8 recommandé"
echo "  - Disque: 100GB"
echo ""
echo "Pour importer dans virt-manager :"
echo "  sudo cp output-local-llm/local-llm.qcow2 /var/lib/libvirt/images/"
echo "  sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/local-llm.qcow2"
echo "  Puis : Fichier > Nouvelle VM > Importer une image disque existante"
echo ""
echo "Connexion SSH:"
echo "  ssh llm@<IP_VM>  (mot de passe: password)"
echo ""
echo "Utilisation:"
echo "  devstral          # Chat interactif avec Devstral"
echo "  vibe              # Mistral Vibe CLI pour le coding"
echo "  models            # Liste des modèles disponibles"
echo "  llm-status        # Status du service Ollama"
