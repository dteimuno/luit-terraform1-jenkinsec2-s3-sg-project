provider "aws" {
  region = "us-east-1"
}

#Create security group
resource "aws_security_group" "luit-sg" {
  name        = "luit-sg"
  description = "Allow port 22 from my IP and port 8080 from anywhere"
  vpc_id      = "<your-vpc-id>"
}
#Create security group rule allowing port 22 from my IP
resource "aws_vpc_security_group_ingress_rule" "allow_22_myip" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = "<your-local-machine-ipv4-address>"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

#Create security group rule allowing port 8080 from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_8080_anywhere" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

#Allow all traffic egress rule
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic-egress_ipv4" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#Create ec2 instance with bootstrap script to install  java and then jenkins
resource "aws_instance" "web" {
  ami             = "ami-04b4f1a9cf54c11d0" #ubuntu us-east-1
  instance_type   = "t2.micro"
  security_groups = ["luit-sg"]
  key_name        = "<your-key-name>"
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
  bucket        = "dtmluitbucket"
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
