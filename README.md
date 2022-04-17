# amazonlinux2022-for-self-hosted-runners
GitHub self-hosted runners running on Amazon Linux 2022.
# usage

## Register Parameter
```
$ GITHUB_PERSONAL_ACCESS_TOKEN=<your personal access token>
$ aws ssm put-parameter \
      --name GITHUB_PERSONAL_ACCESS_TOKEN \
      --value $GITHUB_PERSONAL_ACCESS_TOKEN \
      --type "SecureString"
```

## Create self-hosted runner
```
$ cd terraform
$ terraform init
$ terraform plan
$ terraform apply
```

# Note
- Assumed to run in the ap-northeast-1
- An EC2 instance of t3.small will be built and charged