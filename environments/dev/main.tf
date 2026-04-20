terraform {
  backend "s3" {
    bucket         = "terraform-state-project2-srujana"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# Add a provider block to specify the AWS provider and region
provider "aws" {
  region = "us-east-1"
}

# 1. Create vpc
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
}

# 2. Create internet gateway
resource "aws_internet_gateway" "dev_internet_gateway" {
  vpc_id = aws_vpc.dev_vpc.id
}

# 3. Create route table
resource "aws_route_table" "dev_route_table" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_internet_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.dev_internet_gateway.id
  }

  tags = {
    Name = "Dev_Route_Table"
  }
}

# 4. Create subnet
resource "aws_subnet" "dev_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Dev_Subnet"
  }
}

# 5. Associate route table with subnet
resource "aws_route_table_association" "dev_route_table_association" {
  subnet_id      = aws_subnet.dev_subnet.id
  route_table_id = aws_route_table.dev_route_table.id
}

# 6. Create security group to allow port 80, 22, and 443
resource "aws_security_group" "dev_security_group" {
  name        = "dev_security_group"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Create a network interface
resource "aws_network_interface" "dev_network_interface" {
  subnet_id       = aws_subnet.dev_subnet.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.dev_security_group.id]
}

# 8. Assign an elastic IP to the network interface
resource "aws_eip" "dev_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.dev_network_interface.id
  depends_on        = [aws_internet_gateway.dev_internet_gateway]
}

# 9. Create Ubuntu server and install/enable Apache web server
resource "aws_instance" "dev_web_server_instance" {
  ami                    = "ami-0ec10929233384c7f"
  instance_type          = "t3.micro"
  availability_zone      = "us-east-1a"
  key_name               = "main-key"
  subnet_id              = aws_subnet.dev_subnet.id
  vpc_security_group_ids = [aws_security_group.dev_security_group.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install apache2 -y
              sudo systemctl start apache2
              sudo systemctl enable apache2
              sudo bash -c 'echo "<html><body><h1>Welcome to the Dev Web Server!</h1></body></html>" > /var/www/html/index.html'
              EOF

  tags = {
    Name = "Dev_Web_Server_Instance"
  }
}


