# ==========================================
# 1. AWS GLUE IAM ROLE
# ==========================================

# Create the role that AWS Glue will assume
resource "aws_iam_role" "glue_service_role" {
  name = "olist_glue_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AWS-managed basic policy so Glue can run and write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "glue_service_basic" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Fix: Custom policy giving Glue access ONLY to your NEW Landing and Transformation buckets
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "olist_glue_s3_access"
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.landing_zone.arn,
          "${aws_s3_bucket.landing_zone.arn}/*",
          aws_s3_bucket.transformation_zone.arn,
          "${aws_s3_bucket.transformation_zone.arn}/*"
        ]
      }
    ]
  })
}

# ==========================================
# 2. AMAZON REDSHIFT IAM ROLE
# ==========================================

# Create the role that Redshift will assume
resource "aws_iam_role" "redshift_service_role" {
  name = "olist_redshift_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })
}

# Give Redshift read-only access to S3 so it can read the Iceberg data
resource "aws_iam_role_policy_attachment" "redshift_s3_readonly" {
  role       = aws_iam_role.redshift_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# NEW Fix for Option B: Give Redshift permission to read the Glue Data Catalog (For Redshift Spectrum)
resource "aws_iam_role_policy_attachment" "redshift_glue_catalog" {
  role       = aws_iam_role.redshift_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess" 
}