profile = "erasmo-sre-admin"

vpc = {
  name                 = "ecs-vpc"
  cidr_block           = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_ipv6          = false
  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

aws_security_group_http = {
  name        = "http"
  description = "HTTP traffic"
  vpc_id      = module.vpc.vpc_id
}

aws_security_group_egress_all = {
  name        = "egress-all"
  description = "Allow all outbound traffic"
  vpc_id      = module.vpc.vpc_id
}

alb = {
  name               = "alb-test"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.vpc_public_subnets_ids
}

ecs_task_execution_role = {
  policy_document = {
    actions     = ["sts:AssumeRole"]
    effect      = "Allow"
    type        = "Service"
    identifiers = ["ecs-tasks.amazonaws.com"]
  }
  iam_role_name = "task-execution-role"
  iam_policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

ecs_autoscale_role = {
  policy_document = {
    actions     = ["sts:AssumeRole"]
    effect      = "Allow"
    type        = "Service"
    identifiers = ["application-autoscaling.amazonaws.com"]
  }
  iam_role_name = "ecs-scale-application"
  iam_policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}
// SEE https://github.com/jvk243/terraform-aws-ecs-postgres-docker-flask-example/blob/main/terraform/task_definition.json.tpl
// Consider this as an example https://erik-ekberg.medium.com/terraform-ecs-fargate-example-1397d3ab7f02
ecs_task = {
  family                   = "ecs-task-family"
  container_image_name     = "nginx"
  container_image          = "nginx:alpine"
  container_image_port     = 80
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
}

ecs_service = {
  name            = "ecs_service"
  cluster         = module.ecs_cluster.aws_ecs_cluster_id
  launch_type     = "FARGATE"
  desired_count   = 3
  egress_all_id   = module.alb.aws_sg_egress_all_id
  private_subnets = module.vpc.vpc_private_subnets_ids
}

vpc_id  = module.vpc.vpc_id
alb_arn = module.alb.aws_alb_arn