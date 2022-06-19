# Create a Security Group for the Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Controls access to the ALB"
  vpc_id      = aws_vpc.base_vpc.id

  ingress {
    protocol    = "TCP"
    from_port   = var.inbound_port
    to_port     = var.inbound_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the Application Load Balancer
resource "aws_alb" "alb" {
  name            = "alb"
  subnets         = aws_subnet.public_subnet[*].id
  security_groups = [aws_security_group.alb_sg.id]
}

# Create a HTTP target group for the nginx service
resource "aws_alb_target_group" "tg" {
  name        = "tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.base_vpc.id
  target_type = "ip"

  health_check {
    path = "/actuator/health"
  }
}

# Redirect all traffic from the Application Load Balancer to the Target Group
resource "aws_alb_listener" "listener" {
  load_balancer_arn = aws_alb.alb.id
  port              = var.inbound_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.tg.id
    type             = "forward"
  }
}