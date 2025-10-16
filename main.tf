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

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    ssh_public_key = file(var.ssh_public_key_path)
  }
}

locals {
  gib_in_bytes = 1024 * 1024 * 1024
}

resource "libvirt_network" "vm_network" {
  name      = "terraform_net"
  mode      = "nat"
  domain    = "terraform.test"
  addresses = ["192.168.125.0/24"]
  dhcp {
    enabled = true
  }
  autostart = true
}

resource "libvirt_volume" "base_image" {
  name   = "ubuntu-2204-cloud-image.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "vm_disk" {
  name           = "test-vm-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.base_image.id
  size           = 10 * local.gib_in_bytes # 10GB
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "test-vm-cloudinit.iso"
  pool           = "default"
  user_data      = data.template_file.user_data.rendered
}

resource "libvirt_domain" "test_vm" {
  name   = "test-terraform-vm"
  memory = 2048
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name    = libvirt_network.vm_network.name
    wait_for_lease  = true
  }

  disk {
    volume_id = libvirt_volume.vm_disk.id
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

output "vm_ip_address" {
  value = try(
    libvirt_domain.test_vm.network_interface[0].addresses[0],
    "IP address unavailable."
  )
}

output "ssh_command" {
  value = try(
    "ssh -i id_rsa ubuntu@${libvirt_domain.test_vm.network_interface[0].addresses[0]}",
    "SSH command unavailable, IP address was not received."
  )
}