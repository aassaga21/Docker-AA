resource "openstack_compute_keypair_v2" "keypair_AA" {
  name       = "key-AA"
  public_key = file("C:/Users/alexa/.ssh/id_ed_AA.pub")
}

resource "openstack_networking_secgroup_v2" "sg_AA" {
  name        = "sg-AA-ssh-access"
  description = "Autorise SSH port 22 et ICMP"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_rule_AA" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_AA.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp_rule_AA" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_AA.id
}

resource "openstack_compute_instance_v2" "vm_AA" {
  name            = "vm-e2-AA"
  flavor_name     = "a2-ram4-disk50-perf1"  # 2 vCPU ú 4Go ú 50Go
  image_id        = "1b034438-bbad-41d9-9d86-68c4b0cf933e"  # Ubuntu 24.04 LTS Noble Numbat
  key_pair        = openstack_compute_keypair_v2.keypair_AA.name
  security_groups = [openstack_networking_secgroup_v2.sg_AA.name]

  network {
    name = "ext-net1"
  }

  metadata = {
    classe = "E2"
    module = "docker"
    projet = "GIT-LAB-CLOUD"
    etudiant = "AA"
  }
}

output "vm_AA_ip" {
  value       = openstack_compute_instance_v2.vm_AA.access_ip_v4
  description = "Adresse IP de la VM de AA"
}
