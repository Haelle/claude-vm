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
  default = "100G" # Plus d'espace pour les modèles LLM
}

variable "memory" {
  type    = string
  default = "16384" # 16GB RAM minimum pour Devstral
}

variable "cpus" {
  type    = string
  default = "8" # Plus de CPUs pour l'inférence
}

variable "devstral_model" {
  type    = string
  default = "devstral-small-2" # Peut être changé en "devstral:24b" pour le plus gros modèle
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

  # Installation Ollama
  provisioner "shell" {
    inline = [
      "curl -fsSL https://ollama.com/install.sh | sudo sh",
      "sudo systemctl enable ollama",
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
      "# Installation de Mistral Vibe CLI",
      "$HOME/.local/bin/uv tool install mistral-vibe",
    ]
  }

  # Configuration Vibe CLI pour Ollama local
  provisioner "shell" {
    inline = [
      "mkdir -p ~/.vibe",
      <<-SCRIPT
      cat > ~/.vibe/config.toml << 'TOML'
active_model = "ollama-devstral-small-2"

# ============================================
# PROVIDER OLLAMA
# ============================================
[[providers]]
name = "ollama"
api_base = "http://localhost:11434/v1"
api_key_env_var = ""
api_style = "openai"
backend = "generic"
reasoning_field_name = "reasoning_content"

# ============================================
# MODÈLE
# ============================================
[[models]]
name = "${var.devstral_model}"
provider = "ollama"
alias = "ollama-devstral-small-2"
temperature = 0.2
input_price = 0.0
output_price = 0.0
TOML
      SCRIPT
    ]
  }

  # Installation des dotfiles
  provisioner "shell" {
    inline = [
      "git clone https://github.com/Haelle/dotfiles.git ~/dotfiles",
      "cd ~/dotfiles",
      "./install fish",
      "./install git",
      "./install tmux",
      "./install neovim",
    ]
  }

  # Installation qemu-guest-agent (permet à virt-manager d'afficher l'IP sur certaines distrib host)
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent"
    ]
  }

  # Copie du modèle Devstral (pré-téléchargé pour éviter 40min de download)
  provisioner "file" {
    source      = "models/"
    destination = "/tmp/ollama-models"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/ollama-models /usr/share/ollama/.ollama/models",
      "sudo chown -R ollama:ollama /usr/share/ollama/.ollama/models",
      "# Vérifier que le modèle est bien reconnu",
      "sudo systemctl start ollama",
      "sleep 3",
      "ollama list"
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
