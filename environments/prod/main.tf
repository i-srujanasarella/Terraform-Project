terraform {
  backend "s3" {
    bucket         = "terraform-state-project2-srujana"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Create vpc
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.2.0.0/16"
}

# 2. Create internet gateway
resource "aws_internet_gateway" "prod_internet_gateway" {
  vpc_id = aws_vpc.prod_vpc.id
}

# 3. Create route table
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_internet_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod_internet_gateway.id
  }

  tags = {
    Name = "Prod_Route_Table"
  }
}

# 4. Create subnet
resource "aws_subnet" "prod_subnet" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Prod_Subnet"
  }
}

# 5. Associate route table with subnet
resource "aws_route_table_association" "prod_route_table_association" {
  subnet_id      = aws_subnet.prod_subnet.id
  route_table_id = aws_route_table.prod_route_table.id
}

# 6. Create security group
resource "aws_security_group" "prod_security_group" {
  name        = "prod_security_group"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.prod_vpc.id

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
resource "aws_network_interface" "prod_network_interface" {
  subnet_id       = aws_subnet.prod_subnet.id
  private_ips     = ["10.2.1.10"]
  security_groups = [aws_security_group.prod_security_group.id]
}

# 8. Assign an elastic IP
resource "aws_eip" "prod_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.prod_network_interface.id
  depends_on        = [aws_internet_gateway.prod_internet_gateway]
}

# 9. Create Ubuntu server
resource "aws_instance" "prod_web_server_instance" {
  ami                    = "ami-0ec10929233384c7f"
  instance_type          = "t3.micro"
  availability_zone      = "us-east-1a"
  key_name               = "main-key"
  subnet_id              = aws_subnet.prod_subnet.id
  vpc_security_group_ids = [aws_security_group.prod_security_group.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install apache2 -y
              sudo systemctl start apache2
              sudo systemctl enable apache2
              sudo bash -c 'echo "<html><body><h1>Welcome to the Prod Web Server!</h1></body></html>" > /var/www/html/index.html'
              EOF

  tags = {
    Name = "Prod_Web_Server_Instance"
  }
}
