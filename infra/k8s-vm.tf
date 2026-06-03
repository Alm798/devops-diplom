resource "yandex_compute_image" "ubuntu" {
  source_family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "k8s_master" {
  name        = "k8s-master"
  hostname    = "k8s-master"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.subnet_a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "vm:${file("/home/vm/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_compute_instance" "k8s_worker_1" {
  name        = "k8s-worker-1"
  hostname    = "k8s-worker-1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.subnet_a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "vm:${file("/home/vm/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_compute_instance" "k8s_worker_2" {
  name        = "k8s-worker-2"
  hostname    = "k8s-worker-2"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.subnet_a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "vm:${file("/home/vm/.ssh/id_ed25519.pub")}"
  }
}
