terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.16"
    }
  }
  required_version = "~>1.5.4"
}
provider "aws" {
    region = "us-east-1"
    profile = "superuser"
  
}


resource "aws_launch_configuration" "server-config" {
  image_id        = "ami-06db4d78cb1d3bbf9"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.cluster-sg.id]
  user_data = <<-EOF
                #!/bin/bash

                # Update package list
                sudo apt update -y

                # Install Apache
                sudo apt install apache2 -y

                # Start Apache
                sudo systemctl start apache2

                # Enable Apache to start on boot
                sudo systemctl enable apache2

                # Print a message indicating successful installation
                echo "Apache installed and started successfully!"
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "cluster-sg" {
  name = "cluster-sg"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = var.protocol
    cidr_blocks = var.all_ips
  }
}
resource "aws_autoscaling_group" "cluster-ASG" {
  launch_configuration = aws_launch_configuration.server-config.name
  vpc_zone_identifier  = data.aws_subnets.server-subnets.ids
  target_group_arns    = [aws_lb_target_group.server-target-group.arn]
  health_check_type    = "ELB"
  min_size             = 2
  max_size             = 5
  tag {
    key                 = "Name"
    value               = "cluster-ASG"
    propagate_at_launch = true
  }
}

data "aws_vpc" "server-vpc" {
  default = true
}
data "aws_subnets" "server-subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.server-vpc.id]
  }
}

resource "aws_lb" "server-lb" {
  name               = "server-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.server-subnets.ids
  security_groups    = [aws_security_group.lb-sg.id]
}
resource "aws_lb_listener" "http-listener" {
  load_balancer_arn = aws_lb.server-lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Error 404 ..file not found"
      status_code  = 404
    }
  }
}
#create security group to allow load balancer
resource "aws_security_group" "lb-sg" {
  #allow inbound http requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = var.protocol
    cidr_blocks = var.all_ips
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.all_ips
  }
}

resource "aws_lb_target_group" "server-target-group" {
  name     = "server-target-group"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.server-vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    timeout             = 3
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }


}

resource "aws_lb_listener_rule" "http-listener-rule" {
  listener_arn = aws_lb_listener.http-listener.arn
  condition {
    path_pattern {
      values = ["*"]
    }

  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server-target-group.arn
  }

}

output "alb_dns_name" {
  value       = aws_lb.server-lb.dns_name
  description = "domain of the load balancer"

}