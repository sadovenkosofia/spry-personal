project_name  = "demo"
domain_prefix = "spry-sofia-2026"

callback_urls = [
  "https://db638pojoftlz.cloudfront.net/auth/callback",
  "http://localhost:5173/auth/callback",
]
logout_urls = [
  "https://db638pojoftlz.cloudfront.net/",
  "http://localhost:5173/",
]
allowed_origins = [
  "https://db638pojoftlz.cloudfront.net",
  "http://localhost:5173",
]

report_email = "sadovenkosofia52@gmail.com"

vpc_id            = "vpc-04c4d27407340d580"
subnet_ids        = ["subnet-070b3472394744019", "subnet-0ddbd0c03611fa046", "subnet-05a68af70231192f8"]
security_group_id = "sg-05616c13ae264c1a7"
route_table_id    = "rtb-05cfdbb34f4c3672c"

builder_image_uri = "516387401775.dkr.ecr.eu-central-1.amazonaws.com/spry-backend:reports-bfc5aada24bad48138a3861a1adce54934213d06"
parser_image_uri  = "516387401775.dkr.ecr.eu-central-1.amazonaws.com/spry-backend:ai-508225f2935e323e47e497858e742b9b0f70cb58"