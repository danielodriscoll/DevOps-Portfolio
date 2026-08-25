terraform {
  backend "s3" {
    bucket       = "danielodriscoll-devops-portfolio-tfstate" # the bucket from bootstrap
    key          = "main/terraform.tfstate"                   # path/filename for the state file inside the bucket
    region       = "eu-west-1"                                # must match the bucket's region
    encrypt      = true                                       # encrypt the state file in transit/at rest
    use_lockfile = true                                       # S3-native locking (v1.10+) — no DynamoDB needed
  }
}