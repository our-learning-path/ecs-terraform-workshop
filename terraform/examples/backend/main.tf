module "backend" {
  source = "../../modules/backend"
  backend = {
    bucket_name    = "terraform-backend-state-incode-demo"
    key            = "state/resource.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "resource-backend-lock"
  }
}
