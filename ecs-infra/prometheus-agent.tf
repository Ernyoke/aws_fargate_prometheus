resource "aws_ssm_parameter" "prometheus_config_param" {
  name  = "AmazonCloudWatch-PrometheusConfigName-${aws_ecs_cluster.ecs_cluster.name}-FARGATE-awsvpc"
  type  = "String"
  value = file("./prometheus-config.yml")
}

resource "aws_ssm_parameter" "prometheus_config_ecs_param" {
  name  = "AmazonCloudWatch-CWAgentConfig-${aws_ecs_cluster.ecs_cluster.name}-FARGATE-awsvpc"
  type  = "String"
  value = file("./prometheus-ecs-config.json")
  tier  = "Intelligent-Tiering"
}

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus-agent-sg"
  description = "Controls access to the ALB"
  vpc_id      = aws_vpc.base_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "prometheus_agent" {
  family                   = "cloudwatch-agent-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  container_definitions = templatefile("prometheus-agent-task.tftpl", {
    aws_region                = var.aws_region,
    prometheus_config_content = aws_ssm_parameter.prometheus_config_param.arn,
    cw_config_content         = aws_ssm_parameter.prometheus_config_ecs_param.arn
  })

  execution_role_arn = aws_iam_role.prometheus_agent_execution_role.arn
  task_role_arn      = aws_iam_role.prometheus_agent_task_role.arn
}

resource "aws_ecs_service" "prometheus_agent_ecs_service" {
  name            = "prometheus-agent-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.prometheus_agent.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.prometheus_sg.id]
    subnets         = aws_subnet.private_subnet[*].id
  }
}

resource "aws_iam_role" "prometheus_agent_task_role" {
  name = "prometheus-agent-task-role"

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

resource "aws_iam_policy" "prometheus_agent_task_policy" {
  name        = "prometheus-agent-task-policy"
  path        = "/"
  description = "Task policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:DescribeContainerInstances",
          "ec2:DescribeInstances",
          "ecs:DescribeTaskDefinition"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_agent_task_role_general_attachment" {
  role       = aws_iam_role.prometheus_agent_task_role.id
  policy_arn = aws_iam_policy.prometheus_agent_task_policy.arn
}

resource "aws_iam_role_policy_attachment" "managed_policy_task_role_general_attachment" {
  role       = aws_iam_role.prometheus_agent_task_role.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role" "prometheus_agent_execution_role" {
  name = "prometheus-agent-execution-role"

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

resource "aws_iam_policy" "prometheus_agent_execution_ssm_policy" {
  name        = "prometheus-agent-execution-ssm-policy"
  path        = "/"
  description = "Task policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_agent_execution_role_ssm_attachment" {
  role       = aws_iam_role.prometheus_agent_execution_role.id
  policy_arn = aws_iam_policy.prometheus_agent_execution_ssm_policy.arn
}

resource "aws_iam_policy" "prometheus_agent_execution_general_policy" {
  name        = "prometheus-agent-execution-general-policy"
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

resource "aws_iam_role_policy_attachment" "prometheus_agent_execution_role_general_attachment" {
  role       = aws_iam_role.prometheus_agent_execution_role.id
  policy_arn = aws_iam_policy.prometheus_agent_execution_general_policy.arn
}

resource "aws_iam_role_policy_attachment" "managed_policy_attachment" {
  role       = aws_iam_role.prometheus_agent_execution_role.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "managed_policy_execution_role_attachment" {
  role       = aws_iam_role.prometheus_agent_execution_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}