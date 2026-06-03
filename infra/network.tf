data "yandex_vpc_network" "default" {
  name = "default"
}

data "yandex_vpc_subnet" "subnet_a" {
  name = "default-ru-central1-a"
}

data "yandex_vpc_subnet" "subnet_b" {
  name = "default-ru-central1-b"
}

data "yandex_vpc_subnet" "subnet_d" {
  name = "default-ru-central1-d"
}
