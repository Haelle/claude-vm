packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "ubuntu_version" {
  type    = string
  default = "24.04"
}

variable "iso_path" {
  type    = string
  default = "iso/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "disk_size" {
  type    = string
  default = "100G"  # Plus d'espace pour les modèles LLM
}

variable "memory" {
  type    = string
  default = "16384"  # 16GB RAM minimum pour Devstral
}

variable "cpus" {
  type    = string
  default = "8"  # Plus de CPUs pour l'inférence
}

variable "devstral_model" {
  type    = string
  default = "devstral-small-2"  # Peut être changé en "devstral:24b" pour le plus gros modèle
}

source "qemu" "local-llm" {
  iso_url          = var.iso_path
  iso_checksum     = "none"
  output_directory = "output-local-llm"
  vm_name          = "local-llm.qcow2"
  format           = "qcow2"

  disk_size   = var.disk_size
  memory      = var.memory
  cpus        = var.cpus
  accelerator = "kvm"

  # Mettre à false pour debug
  headless = true

  ssh_username     = "llm"
  ssh_password     = "password"
  ssh_timeout      = "30m"
  shutdown_command = "echo 'password' | sudo -S shutdown -P now"

  # Autoinstall (Ubuntu Server 24.04)
  http_directory = "http-llm"
  boot_wait      = "10s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
}

build {
  sources = ["source.qemu.local-llm"]

  # Installation de Docker
  provisioner "shell" {
    inline = [
      "echo 'password' | sudo -S apt-get update",
      "sudo apt-get install -y ca-certificates curl git vim htop tmux",

      "# Installation Docker",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",

      "echo \"Types: deb\" | sudo tee /etc/apt/sources.list.d/docker.sources",
      "echo \"URIs: https://download.docker.com/linux/ubuntu\" | sudo tee -a /etc/apt/sources.list.d/docker.sources",
      "echo \"Suites: noble\" | sudo tee -a /etc/apt/sources.list.d/docker.sources",
      "echo \"Components: stable\" | sudo tee -a /etc/apt/sources.list.d/docker.sources",
      "echo \"Signed-By: /etc/apt/keyrings/docker.asc\" | sudo tee -a /etc/apt/sources.list.d/docker.sources",

      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker llm",
      "sudo systemctl enable docker"
    ]
  }

  # Installation de Podman
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y podman",
      "# Configuration pour permettre rootless containers",
      "sudo touch /etc/subuid /etc/subgid",
      "sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 llm"
    ]
  }

  # Installation Oh My ZSH
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y zsh",
      "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" -- --unattended",
      "sudo chsh -s /usr/bin/zsh llm"
    ]
  }

  # Installation Ollama
  provisioner "shell" {
    inline = [
      "curl -fsSL https://ollama.com/install.sh | sudo sh",
      "sudo systemctl enable ollama",
      "# Démarrer Ollama pour le pull du modèle",
      "sudo systemctl start ollama",
      "sleep 5"
    ]
  }

  # Téléchargement du modèle Devstral
  provisioner "shell" {
    inline = [
      "# Attendre qu'Ollama soit prêt",
      "for i in $(seq 1 30); do curl -s http://localhost:11434/api/tags > /dev/null && break || sleep 2; done",
      "# Pull du modèle Devstral",
      "ollama pull ${var.devstral_model}",
      "# Vérifier que le modèle est bien téléchargé",
      "ollama list"
    ]
  }

  # Installation Python + Mistral Vibe CLI
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3 python3-pip python3-venv pipx",
      "# Installation de uv (gestionnaire de packages Python rapide)",
      "curl -LsSf https://astral.sh/uv/install.sh | sh",
      "# Ajouter uv au PATH",
      "export PATH=\"$HOME/.local/bin:$PATH\"",
      "echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.zshrc",
      "# Installation de Mistral Vibe CLI",
      "$HOME/.local/bin/uv tool install mistral-vibe",
      "# Configuration pour utiliser Ollama en local",
      "echo 'export OLLAMA_HOST=http://localhost:11434' >> ~/.zshrc",
    ]
  }

  # Configuration des aliases et outils utiles
  provisioner "shell" {
    inline = [
      "# Aliases pour le développement",
      "echo '' >> ~/.zshrc",
      "echo '# Aliases LLM' >> ~/.zshrc",
      "echo 'alias devstral=\"ollama run devstral\"' >> ~/.zshrc",
      "echo 'alias llm-status=\"systemctl status ollama\"' >> ~/.zshrc",
      "echo 'alias llm-logs=\"journalctl -u ollama -f\"' >> ~/.zshrc",
      "echo 'alias models=\"ollama list\"' >> ~/.zshrc",
      "# Script de démarrage rapide",
      "echo '#!/bin/bash' | sudo tee /usr/local/bin/llm-start",
      "echo 'sudo systemctl start ollama' | sudo tee -a /usr/local/bin/llm-start",
      "echo 'echo \"Ollama démarré. Modèles disponibles:\"' | sudo tee -a /usr/local/bin/llm-start",
      "echo 'ollama list' | sudo tee -a /usr/local/bin/llm-start",
      "sudo chmod +x /usr/local/bin/llm-start"
    ]
  }

  # Nettoyage pour template (mais on garde les modèles LLM)
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo apt-get autoremove -y",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo cloud-init clean --logs || true",
      "sync"
    ]
  }
}
