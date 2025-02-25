packer {
  required_plugins {
    hyperv = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/hyperv"
    }
  }
}

variable "ssh_password" {
  type    = string
}

variable "vm_path" {
  type    = string
}

variable "memory" {
  type    = string
}

variable "cpus" {
  type    = string
}

variable "disk_size" {
  type    = string
}

source "hyperv-iso" "debian12" {
  generation         = 2
  iso_url            = "https://mirrors.ocf.berkeley.edu/debian-cd/12.9.0/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso"
  iso_checksum       = "1257373c706d8c07e6917942736a865dfff557d21d76ea3040bb1039eb72a054"
  communicator       = "ssh"
  ssh_username       = "node"
  ssh_password       = var.ssh_password
  ssh_timeout        = "60m"
  shutdown_command   = "echo '${var.ssh_password}' | sudo -S halt -p"
  cpus               = var.cpus
  memory             = var.memory
  disk_size          = var.disk_size
  switch_name        = "Default Switch"
  http_directory     = "./packer/http"
  boot_wait          = "5s"
  keep_registered     = false
  boot_command = [
    "c<wait>",
    "linux /install.amd/vmlinuz ",
    "auto=true ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=node-base ",
    "domain=local ",
    "interface=auto ",
    "vga=788 noprompt quiet --<enter>",
    "initrd /install.amd/initrd.gz<enter>",
    "boot<enter>"
  ]
}

build {
  source "hyperv-iso.debian12" {
    vm_name = "node-base"
    output_directory = "${var.vm_path}\\node-base"
  }

  provisioner "file" {
    source      = "./packer/provision.sh"
    destination = "/tmp/provision.sh"
  }

  provisioner "file" {
    source = "./data/id_rsa.pub"
    destination = "/tmp/id_rsa.pub"
  }

  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash /tmp/provision.sh"
    ]
  }
}
