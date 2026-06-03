output "k8s_master_external_ip" {
  value = yandex_compute_instance.k8s_master.network_interface[0].nat_ip_address
}

output "k8s_master_internal_ip" {
  value = yandex_compute_instance.k8s_master.network_interface[0].ip_address
}

output "k8s_worker_1_external_ip" {
  value = yandex_compute_instance.k8s_worker_1.network_interface[0].nat_ip_address
}

output "k8s_worker_1_internal_ip" {
  value = yandex_compute_instance.k8s_worker_1.network_interface[0].ip_address
}

output "k8s_worker_2_external_ip" {
  value = yandex_compute_instance.k8s_worker_2.network_interface[0].nat_ip_address
}

output "k8s_worker_2_internal_ip" {
  value = yandex_compute_instance.k8s_worker_2.network_interface[0].ip_address
}
