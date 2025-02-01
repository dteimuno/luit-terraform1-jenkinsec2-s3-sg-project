# luit-terraform1-jenkinsec2-s3-sg-project
**Part 1**
Here's a **Markdown explanation** of your Terraform script:  

---

# **Terraform AWS Infrastructure Explanation**

## **1. Provider Configuration**
```hcl
provider "aws" {
  region = "us-east-1"
}
```
- Specifies AWS as the cloud provider.  
- Sets the region to **`us-east-1`** where all resources will be deployed.  

---

## **2. Security Group Creation**
```hcl
resource "aws_security_group" "luit-sg" {
  name        = "luit-sg"
  description = "Allow port 22 from my IP and port 8080 from anywhere"
  vpc_id      = "<your-vpc-id>"
}
```
- Creates a **security group** named `luit-sg`.  
- Allows controlled inbound and outbound traffic.  
- Must be assigned to a **VPC (Virtual Private Cloud)**.  

---

## **3. Security Group Ingress Rules**
### **Allow SSH (Port 22) from a Specific IP**
```hcl
resource "aws_vpc_security_group_ingress_rule" "allow_22_myip" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = "<your-local-machine-ipv4-address>"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
```
- Restricts SSH access to **only** your **local machine IP**.  
- Ensures unauthorized users cannot SSH into the instance.  

### **Allow Jenkins UI (Port 8080) from Anywhere**
```hcl
resource "aws_vpc_security_group_ingress_rule" "allow_8080_anywhere" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}
```
- Allows incoming traffic on **port 8080** (used by Jenkins).  
- Open to **any IP address** (`0.0.0.0/0`).  

---

## **4. Security Group Egress Rule (Allow All Outbound Traffic)**
```hcl
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic-egress_ipv4" {
  security_group_id = aws_security_group.luit-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
```
- Allows the instance to make outbound requests (e.g., downloading packages, accessing the internet).  
- `"-1"` means **all protocols and ports** are allowed.  

---

## **5. EC2 Instance Creation**
```hcl
resource "aws_instance" "web" {
  ami             = "ami-04b4f1a9cf54c11d0" # Ubuntu in us-east-1
  instance_type   = "t2.micro"
  security_groups = ["luit-sg"]
  key_name        = "<your-key-name>"
  user_data       = <<-EOF
                        #!/bin/bash
                        sudo apt update -y
                        sudo apt install -y fontconfig openjdk-17-jre
                        sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian/jenkins.io-2023.key
                        echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
                        sudo apt update -y
                        sudo apt install -y jenkins
                        sudo systemctl enable jenkins
                        sudo systemctl start jenkins
                        EOF
}
```
- Creates an **EC2 instance** running **Ubuntu**.  
- Uses **t2.micro** (eligible for AWS Free Tier).  
- Attaches the `luit-sg` **security group**.  
- **Bootstrap Script (`user_data`)**:
  - Installs **OpenJDK 17** (required for Jenkins).  
  - Downloads and installs **Jenkins**.  
  - Starts Jenkins as a system service.  

---

## **6. S3 Bucket Creation**
```hcl
resource "aws_s3_bucket" "dtmluitbucket" {
  bucket        = "dtmluitbucket"
  force_destroy = true
}
```
- Creates an **S3 bucket** named `dtmluitbucket`.  
- `force_destroy = true` ensures it can be deleted with Terraform.  

---

## **7. S3 Bucket Ownership Controls**
```hcl
resource "aws_s3_bucket_ownership_controls" "luit-bucket-ownership" {
  bucket = aws_s3_bucket.dtmluitbucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
```
- Ensures **bucket owner** has full control over objects.  

---

## **8. S3 Bucket ACL (Private Access)**
```hcl
resource "aws_s3_bucket_acl" "luit-bucket-policy" {
  depends_on = [aws_s3_bucket_ownership_controls.luit-bucket-ownership]
  bucket = aws_s3_bucket.dtmluitbucket.id
  acl    = "private"
}
```
- Sets the bucket **access control list (ACL) to private**.  

---

## **9. Block Public Access to S3 Bucket**
```hcl
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.dtmluitbucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```
- **Blocks all public access** to prevent accidental exposure.  

---

## **10. Disable S3 Bucket Versioning**
```hcl
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.dtmluitbucket.id
  versioning_configuration {
    status = "Disabled"
  }
}
```
- Disables **versioning**, preventing multiple versions of files from being stored.  

---

# **Summary of Terraform Infrastructure**
| **Component**   | **Description** |
|----------------|----------------|
| **AWS Provider** | Sets up Terraform to manage AWS resources. |
| **Security Group** | Defines rules for inbound/outbound traffic. |
| **EC2 Instance** | Deploys an Ubuntu instance and installs Jenkins. |
| **S3 Bucket** | Creates a private S3 bucket with restricted access. |

### **Next Steps**
1. **Apply the Terraform Configuration**
   ```sh
   terraform init
   terraform apply -auto-approve
   ```
2. **Access Jenkins**
   - Get the **public IP** of the instance:
     ```sh
     terraform output
     ```
   - Open in browser:
     ```
     http://<INSTANCE_PUBLIC_IP>:8080
     ```
   - Get the initial admin password:
     ```sh
     ssh -i <your-key.pem> ubuntu@<INSTANCE_PUBLIC_IP>
     sudo cat /var/lib/jenkins/secrets/initialAdminPassword
     ```

---

### 🚀 **Congratulations! You have successfully deployed Jenkins on AWS using Terraform!**  

Let me know if you need any modifications. 😃
