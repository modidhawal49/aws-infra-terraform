provider "aws" {
  region                   = var.region
  shared_credentials_files = ["~/.aws/credentials"]
}

provider "aws" {
  alias  = "us_east_1"
  region = var.us_east_1_region
}
