provider "aws" {
  region = var.default_aws_region
}

#Create security group
resource "aws_security_group" "luit-sg" {
  name        = "luit-sg"
  description = "Allow port 22 from my IP and port 8080 from anywhere"
  vpc_id      = var.vpc_id
}
#Create security group rule allowing port 22 from my IP
resource "aws_vpc_security_group_ingress_rule" "allow_22_myip" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = var.my_pc_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

#Create security group rule allowing port 8080 from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_8080_anywhere" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = var.access_from_anywhere_cidr
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

#Allow all traffic egress rule
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic-egress_ipv4" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = var.access_from_anywhere_cidr
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#Create ec2 instance with bootstrap script
resource "aws_instance" "web" {
  ami             = var.ubuntu-us-east-1-ami
  instance_type   = var.instance_size
  security_groups = [var.security_group_name]
  key_name        = var.keypair_name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  user_data       = <<-EOF
                        #!/bin/bash
                        sudo apt update -y
                        sudo apt install -y  fontconfig openjdk-17-jre
                        sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian/jenkins.io-2023.key
                        echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
                        sudo apt update -y
                        sudo apt install -y jenkins
                        sudo systemctl enable jenkins
                        sudo systemctl start jenkins
                        EOF
}

resource "aws_s3_bucket" "dtmluitbucket" {
  bucket        = var.bucket_name
  force_destroy = true

}

#Set bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "luit-bucket-ownership" {
  bucket = aws_s3_bucket.dtmluitbucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#Set  bucket policy
resource "aws_s3_bucket_acl" "luit-bucket-policy" {
  depends_on = [aws_s3_bucket_ownership_controls.luit-bucket-ownership]

  bucket = aws_s3_bucket.dtmluitbucket.id
  acl    = "private"
}

#Block all s3 bucket public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.dtmluitbucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#Disablebucket versioning
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.dtmluitbucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

#Create IAM policy for ec2 instance with s3 bucket read/write access
resource "aws_iam_role_policy" "my_policy" {
  name = "s3-full-access-for-ec2"
  role = aws_iam_role.ec2_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
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

#Create IAM role for ec2 instance with s3 bucket read/write access

resource "aws_iam_role" "ec2_role" {
  name = "jenkins-ec2-role-with-s3-access"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
