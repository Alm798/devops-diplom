terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.140"
    }
  }
}

provider "yandex" {
  folder_id = "b1gvedmk37mbe9lcmg32"
  zone      = "ru-central1-a"

  service_account_key_file = "/home/vm/keys/terraform-sa-key.json"
}
