module "network" {
  source             = "./modules/network"
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
}

module "ssm" {
  source       = "./modules/ssm"
  project_name = var.project_name
  environment  = var.environment
  secrets      = local.secrets
}

module "ec2" {
  source                 = "./modules/ec2"
  project_name           = var.project_name
  environment            = var.environment
  secret_arns            = module.ssm.secret_arns
  vpc_security_group_ids = [module.network.ec2_security_group_id]
  subnet_id              = module.network.subnet_id
  s3_config_bucket_arn   = module.s3_bucket.s3_bucket_arn
  s3_config_bucket_name  = module.s3_bucket.s3_bucket_id
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.s3_config_bucket_name
  acl    = "private"  # TODO - grant access to EC2

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}

module "s3_objects" {
  for_each = fileset(local.upload_directory, "**/*.*")
  source = "terraform-aws-modules/s3-bucket/aws//modules/object"

  bucket = module.s3_bucket.s3_bucket_id
  key = "${each.key}"
  file_source = "${path.cwd}/config/${each.key}"

  tags = {
    Sensitive = false
  }
}