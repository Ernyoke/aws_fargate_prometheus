# Allow traffic from the Application Load Balancer to the ECS task
resource "aws_security_group" "task_sg" {
  name        = "task-sg"
  description = "Allow inbound access from the ALB only"
  vpc_id      = aws_vpc.base_vpc.id

  ingress {
    protocol        = "TCP"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    protocol        = "TCP"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.prometheus_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "cwmetrics" {
  family                   = "cwmetrics"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  container_definitions = templatefile("task.tftpl", {
    fargate_cpu    = var.cpu
    fargate_memory = var.memory
    app_image      = "${data.terraform_remote_state.ecr.outputs.registry_url}:latest"
    port           = var.container_port
    aws_region     = var.aws_region
  })

  execution_role_arn = aws_iam_role.task_role.arn
  task_role_arn      = aws_iam_role.task_role.arn
}

resource "aws_ecs_service" "cwmetrics_ecs_service" {
  name            = "cwmetrics-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.cwmetrics.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.task_sg.id]
    subnets         = aws_subnet.private_subnet[*].id
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.tg.id
    container_name   = "cwmetrics"
    container_port   = var.container_port
  }

  depends_on = [aws_alb_listener.listener]
}

resource "aws_iam_role" "task_role" {
  name = "task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "task_policy_general" {
  name        = "task_policy_general"
  path        = "/"
  description = "Task policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_role_general_attachment" {
  role       = aws_iam_role.task_role.id
  policy_arn = aws_iam_policy.task_policy_general.arn
}

output "arn" {
  value = aws_ecs_task_definition.cwmetrics.arn
}