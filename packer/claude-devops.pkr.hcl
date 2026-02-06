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
  default = "20G"
}

variable "memory" {
  type    = string
  default = "4096"
}

variable "cpus" {
  type    = string
  default = "2"
}

source "qemu" "claude-devops" {
  iso_url          = var.iso_path
  iso_checksum     = "none"
  output_directory = "output-claude-devops"
  vm_name          = "claude-devops.qcow2"
  format           = "qcow2"

  disk_size         = var.disk_size
  memory            = var.memory
  cpus              = var.cpus
  accelerator       = "kvm"

  headless = false

  ssh_username     = "claude"
  ssh_password     = "password"
  ssh_timeout      = "30m"
  shutdown_command = "echo 'password' | sudo -S shutdown -P now"

  # Autoinstall (Ubuntu Server 24.04)
  http_directory = "http"
  boot_wait      = "10s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
}

build {
  sources = ["source.qemu.claude-devops"]

  # Installation de Docker
  provisioner "shell" {
    inline = [
      "echo 'password' | sudo -S apt-get update",
      "sudo apt-get install -y ca-certificates curl git vim htop",

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
      "sudo usermod -aG docker claude",
      "sudo systemctl enable docker"
    ]
  }

  # Installation Oh My ZSH
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y zsh",
      "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" -- --unattended",
      "sudo chsh -s /usr/bin/zsh claude"
    ]
  }

  # Installation Terraform + provider libvirt (pour piloter l'hyperviseur du host)
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y gnupg software-properties-common",

      "# Installation Terraform (repo HashiCorp)",
      "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg",
      "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com noble main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list",
      "sudo apt-get update",
      "sudo apt-get install -y terraform",

      "# Dépendances libvirt (client + dev pour le provider terraform-provider-libvirt)",
      "sudo apt-get install -y libvirt-clients libvirt-dev virtinst qemu-utils"
    ]
  }

  # Installation Claude Code
  provisioner "shell" {
    inline = [
      "curl -fsSL https://claude.ai/install.sh | bash"
    ]
  }

  # Nettoyage pour template
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
