locals {
  prefix = "self-hosted-runners-test"
  # AmazonLinux2022/x64_64
  image_id = "ami-0ee292f7955275f8c"
  # x64_64 image is used, so graviton2-based types cannot be used.
  instance_type    = "t3.small"
  label            = local.prefix
  desired_capacity = 1
  max_size         = 1
  min_size         = 1
}