terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file."
  type        = string
}

locals {
  gib_in_bytes = 1024 * 1024 * 1024
}

resource "libvirt_network" "vm_network" {
  name      = "terraform_net"
  mode      = "nat"
  addresses = ["192.168.125.0/24"]
  dhcp {
    enabled = false
  }
  dns {
    enabled = false
  }
  autostart = true
}


resource "libvirt_volume" "base_image" {
  name   = "ubuntu-2204-cloud-image.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "nginx_disk" {
  name           = "nginx-vm-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.base_image.id
}

resource "libvirt_volume" "backend_disk" {
  name           = "backend-vm-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.base_image.id
}

resource "libvirt_cloudinit_disk" "nginx_init" {
  name = "nginx-vm-cloudinit.iso"

  user_data = templatefile(
      "${path.module}/nginx_cloud_init.yml", {
        ssh_public_key = file(var.ssh_public_key_path)
      }
    )
}

resource "libvirt_cloudinit_disk" "backend_init" {
  name = "backend-vm-cloudinit.iso"

  user_data = templatefile(
      "${path.module}/backend_cloud_init.yml", {
        ssh_public_key = file(var.ssh_public_key_path)
      }
    )
}

resource "libvirt_domain" "nginx_vm" {
  name   = "nginx vm"
  memory = 512
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.nginx_init.id

  network_interface {
    network_name = libvirt_network.vm_network.name
    network_id = libvirt_network.vm_network.id
    addresses = ["192.168.125.10"]
    hostname = "nginx"
    wait_for_lease  = false
  }

  disk {
    volume_id = libvirt_volume.nginx_disk.id
  }
  
  graphics {
    type = "spice"
    listen_type = "address"
  }

  console {
    type = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

resource "libvirt_domain" "backend_vm" {
  name   = "backend vm"
  memory = 512
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.backend_init.id

  network_interface {
    network_name = libvirt_network.vm_network.name
    network_id = libvirt_network.vm_network.id
    addresses = ["192.168.125.20"]
    hostname = "backend"
    wait_for_lease  = false
  }

  disk {
    volume_id = libvirt_volume.backend_disk.id
  }
  
  graphics {
    type = "spice"
    listen_type = "address"
  }

  console {
    type = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

output "nginx_ssh_command" {
  value = try(
    "ssh ubuntu@${libvirt_domain.nginx_vm.network_interface[0].addresses[0]}",
    "SSH command unavailable, IP address was not received."
  )
}

output "backend_ssh_command" {
  value = try(
    "ssh ubuntu@${libvirt_domain.backend_vm.network_interface[0].addresses[0]}",
    "SSH command unavailable, IP address was not received."
  )
}