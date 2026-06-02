terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.206.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  folder_id                = var.folder_id
  zone                     = var.zone
}
