Alright, let’s break this down in Markdown!

---

# Explanation of Terraform Configuration

This Terraform configuration sets up an AWS environment with an EC2 instance running Jenkins, S3 bucket configurations, security groups, and IAM roles.

## Provider Configuration

```hcl
provider "aws" {
  region = var.default_aws_region
}
```

- **provider "aws"**: Specifies the AWS provider, with the region defined by the variable `var.default_aws_region`.

---

## Security Group Setup

### Create a Security Group

```hcl
resource "aws_security_group" "luit-sg" {
  name        = "luit-sg"
  description = "Allow port 22 from my IP and port 8080 from anywhere"
  vpc_id      = var.vpc_id
}
```

- **aws_security_group "luit-sg"**: Creates a security group named “luit-sg.”
- **vpc_id**: The VPC ID where this security group will be created.

### Security Group Rules

**Allow SSH (port 22) from a specific IP:**

```hcl
resource "aws_vpc_security_group_ingress_rule" "allow_22_myip" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = var.my_pc_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
```

- **cidr_ipv4**: Allows SSH access from a specific IP address defined by `var.my_pc_ip`.

**Allow HTTP (port 8080) from anywhere:**

```hcl
resource "aws_vpc_security_group_ingress_rule" "allow_8080_anywhere" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = var.access_from_anywhere_cidr
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}
```

- **cidr_ipv4**: Allows access to port 8080 from anywhere (typically for web traffic).

**Allow all outbound traffic:**

```hcl
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic-egress_ipv4" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = var.access_from_anywhere_cidr
  ip_protocol       = "-1" # allows all protocols
}
```

- **ip_protocol = "-1"**: Allows all outbound traffic, unrestricted.

---

## EC2 Instance Setup

```hcl
resource "aws_instance" "web" {
  ami                  = var.ubuntu-us-east-1-ami
  instance_type        = var.instance_size
  security_groups      = [var.security_group_name]
  key_name             = var.keypair_name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  user_data            = <<-EOF
                            #!/bin/bash
                            sudo apt update -y
                            sudo apt install -y fontconfig openjdk-17-jre
                            sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian/jenkins.io-2023.key
                            echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
                            sudo apt update -y
                            sudo apt install -y jenkins
                            sudo systemctl enable jenkins
                            sudo systemctl start jenkins
                        EOF
}
```

- **user_data**: A bootstrap script to set up Jenkins on the EC2 instance.
- **security_groups**: Attaches the created security group.
- **iam_instance_profile**: Provides the instance with the necessary IAM role.

---

## S3 Bucket Configuration

**Create an S3 Bucket:**

```hcl
resource "aws_s3_bucket" "dtmluitbucket" {
  bucket        = var.bucket_name
  force_destroy = true
}
```

- **force_destroy**: Deletes all objects in the bucket when destroying.

**Set Bucket Ownership Controls:**

```hcl
resource "aws_s3_bucket_ownership_controls" "luit-bucket-ownership" {
  bucket = aws_s3_bucket.dtmluitbucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
```

- **object_ownership = "BucketOwnerPreferred"**: Ensures that the bucket owner has control over newly uploaded objects.

**Set Bucket ACL Policy:**

```hcl
resource "aws_s3_bucket_acl" "luit-bucket-policy" {
  depends_on = [aws_s3_bucket_ownership_controls.luit-bucket-ownership]
  bucket     = aws_s3_bucket.dtmluitbucket.id
  acl        = "private"
}
```

- **acl = "private"**: Restricts access to the bucket, making it private.

**Block Public Access:**

```hcl
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.dtmluitbucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

- **block_public_acls**, **block_public_policy**: Prevents public access to the bucket.

**Disable Bucket Versioning:**

```hcl
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.dtmluitbucket.id
  versioning_configuration {
    status = "Disabled"
  }
}
```

- **status = "Disabled"**: Ensures versioning is turned off.

---

## IAM Configuration

**Create an IAM Role:**

```hcl
resource "aws_iam_role" "ec2_role" {
  name = "jenkins-ec2-role-with-s3-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
```

- **assume_role_policy**: Allows EC2 to assume this role.

**Attach IAM Policy to Role:**

```hcl
resource "aws_iam_role_policy" "my_policy" {
  name = "s3-full-access-for-ec2"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "s3-object-lambda:*"
            ],
            "Resource": "*"
        }
    ]
  })
}
```

- **policy**: Grants the EC2 instance full access to S3.

**Create an Instance Profile:**

```hcl
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}
```

- **instance profile**: Links the IAM role to the EC2 instance.

