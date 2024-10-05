# Main VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true  
  enable_dns_hostnames = true   

  tags = {
    Name = "MainVPC"
  }
}


# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.public_subnets[0]
  availability_zone = "us-east-1a"

  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.public_subnets[1]
  availability_zone = "us-east-1b"

  tags = {
    Name = "PublicSubnet2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainIGW"
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "LBSecurityGroup"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDSSecurityGroup"
  }
}

# Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "WebLoadBalancer"
  }
}

# Data Source for Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon's official AMI account ID
}

# Launch Template for EC2
resource "aws_launch_template" "web_template" {
  name          = "web-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "WebASG"
    propagate_at_launch = true
  }
}

# Subnet Group for RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "RDSSubnetGroup"
  }
}

# RDS Database Instance
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = var.db_name # Correct argument
  username             = "admin"
  password             = "password123"
  publicly_accessible  = true
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "MainDB"
  }
}
