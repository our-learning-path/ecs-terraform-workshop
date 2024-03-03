module "ecs_task_execution_role" {
  source = "../ecs_application_role"
  policy_document = {
    actions     = var.ecs_task_execution_role.policy_document.actions
    effect      = var.ecs_task_execution_role.policy_document.effect
    type        = var.ecs_task_execution_role.policy_document.type
    identifiers = var.ecs_task_execution_role.policy_document.identifiers
  }
  iam_role_name  = var.ecs_task_execution_role.iam_role_name
  iam_policy_arn = var.ecs_task_execution_role.iam_policy_arn
}
## --------------------------------------------------------------------------- ##
## FIXME. THis Role should be created following the same approach as the rest of the roles ##
variable "name" {
  default = "golang-api"
}
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name}-ecsTaskRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "dynamodb" {
  name        = "${var.name}-task-policy-dynamodb"
  description = "Policy that allows access to DynamoDB"

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Effect": "Allow",
           "Action": [
               "dynamodb:CreateTable",
               "dynamodb:UpdateTimeToLive",
               "dynamodb:PutItem",
               "dynamodb:DescribeTable",
               "dynamodb:ListTables",
               "dynamodb:DeleteItem",
               "dynamodb:GetItem",
               "dynamodb:Scan",
               "dynamodb:Query",
               "dynamodb:UpdateItem",
               "dynamodb:UpdateTable"
           ],
           "Resource": "*"
       }
   ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dynamodb.arn
}
## --------------------------------------------------------------------------- ##


resource "aws_ecs_task_definition" "ecs_task" {
  family                   = var.ecs_task.family
  cpu                      = var.ecs_task.cpu
  memory                   = var.ecs_task.memory
  requires_compatibilities = var.ecs_task.requires_compatibilities
  network_mode             = var.ecs_task.network_mode
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
  container_definitions = jsonencode([{
    name      = var.ecs_task.container_image_name
    image     = var.ecs_task.container_image
    cpu       = var.ecs_task.cpu
    memory    = var.ecs_task.memory
    essential = true
    portMappings = [{
      containerPort = var.ecs_task.container_image_port
    }],
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.cloudwatch_log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = var.ecs_task.container_image_name
      }
    }
    environment = var.ecs_task.environment
  }])
}
resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service.name
  cluster         = var.ecs_service.cluster
  task_definition = aws_ecs_task_definition.ecs_task.arn
  launch_type     = var.ecs_service.launch_type
  desired_count   = var.ecs_service.desired_count

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_tg_api.arn
    container_name   = var.ecs_task.container_image_name
    container_port   = var.ecs_task.container_image_port
  }

  network_configuration {
    assign_public_ip = false

    security_groups = [
      var.ecs_service.egress_all_id,
      aws_security_group.ingress_api.id,
    ]

    subnets = var.ecs_service.private_subnets
  }
}

resource "aws_lb_target_group" "lb_tg_api" {
  name        = "lb-tg-fiber-api"
  port        = var.ecs_task.container_image_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled = true
    path    = "/"
  }
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = var.alb_arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg_api.arn
  }
}

resource "aws_security_group" "ingress_api" {
  name        = "ingress-api"
  description = "Allow ingress to API"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.ecs_task.container_image_port
    to_port     = var.ecs_task.container_image_port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## --------------------------------------------------------------------------- ##

module "ecs_autoscale_role" {
  source = "../ecs_application_role"
  policy_document = {
    actions     = var.ecs_autoscale_role.policy_document.actions
    effect      = var.ecs_autoscale_role.policy_document.effect
    type        = var.ecs_autoscale_role.policy_document.type
    identifiers = var.ecs_autoscale_role.policy_document.identifiers
  }
  iam_role_name  = var.ecs_autoscale_role.iam_role_name
  iam_policy_arn = var.ecs_autoscale_role.iam_policy_arn
}

## --------------------------------------------------------------------------- ##

resource "aws_appautoscaling_target" "ecs_target" {
  min_capacity       = 1
  max_capacity       = 4
  resource_id        = "service/${var.ecs_service.cluster}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = module.ecs_autoscale_role.iam_role_arn
}

resource "aws_appautoscaling_policy" "appautoscaling_policy_cpu" {
  name               = "application-scale-policy-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "appautoscaling_policy_memory" {
  name               = "application-scale-policy-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization_alarm" {
  alarm_name          = var.cloudwatch_metric_alarm_name
  alarm_description   = "Alarm for high CPU utilization in ECS"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cloudwatch_metric_alarm_cpu_utilization_threshold
  evaluation_periods  = 1
  period              = 60
  statistic           = "Average"
  alarm_actions       = var.cloudwatch_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization_alarm" {
  alarm_name          = "ecs-memory-utilization-alarm"
  alarm_description   = "Alarm for high memory utilization in ECS"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cloudwatch_metric_alarm_memory_utilization_threshold
  evaluation_periods  = 1
  period              = 60
  statistic           = "Average"
  alarm_actions       = var.cloudwatch_alarm_actions
}

resource "aws_cloudwatch_log_group" "ecs_container_logs" {
  name = var.cloudwatch_log_group_name
}
