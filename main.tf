terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ==========================================
# 1. DATA LAKEHOUSE STORAGE (Amazon S3)
# ==========================================

# Renamed to match your new Landing Zone
resource "aws_s3_bucket" "landing_zone" {
  bucket        = "olist-landing-zone-${random_id.bucket_suffix.hex}"
  force_destroy = true 
}

# Renamed to match your new Transformation Zone (Iceberg)
resource "aws_s3_bucket" "transformation_zone" {
  bucket        = "olist-transformation-zone-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# ==========================================
# 2. METADATA CATALOG (AWS Glue)
# ==========================================

resource "aws_glue_catalog_database" "olist_database" {
  name = "olist_lakehouse_db"
}

# ==========================================
# 3. AWS GLUE DATA QUALITY
# ==========================================

# This creates an automated check to ensure your customer data is clean
resource "aws_glue_data_quality_ruleset" "customer_checks" {
  name        = "olist_customer_quality_checks"
  description = "Ensures no nulls in customer IDs"
  
  ruleset = "Rules = [ IsComplete \"customer_unique_id\" ]"
#  target_table {
#    database_name = aws_glue_catalog_database.olist_database.name
#    table_name    = "dim_customers"
#  }
}

# ==========================================
# 4. ALERTING & MONITORING (Amazon SNS)
# ==========================================

resource "aws_sns_topic" "data_alerts" {
  name = "olist-data-pipeline-alerts"
}

resource "aws_sns_topic" "warehouse_alerts" {
  name = "olist-warehouse-alerts"
}

resource "aws_sns_topic" "orchestration_alerts" {
  name = "olist-orchestration-alerts"
}

# ==========================================
# 5. DATA WAREHOUSE (Amazon Redshift)
# ==========================================

#resource "aws_redshift_cluster" "data_warehouse" {
#  cluster_identifier  = "olist-redshift-cluster"
#  database_name       = "olist_dw"
#  master_username     = "admin"
#  master_password     = "SuperSecretPassword123!" 
 # node_type           = "dc2.large"               
  #cluster_type        = "single-node"             
  #skip_final_snapshot = true                      
#}

# ==========================================
# 6. ELT ENGINE (AWS Glue Job for Iceberg)
# ==========================================

resource "aws_glue_job" "pyspark_iceberg_transform" {
  name     = "olist_iceberg_clean_and_convert"
  role_arn = aws_iam_role.glue_service_role.arn 
  
  glue_version      = "4.0" 
  worker_type       = "G.1X"
  number_of_workers = 2 

  command {
    name            = "glueetl" 
    script_location = "s3://${aws_s3_bucket.transformation_zone.bucket}/scripts/iceberg_transform.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = "/aws-glue/jobs/logs-v2/"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    
    # MAGIC CONFIGURATIONS FOR APACHE ICEBERG:
    "--datalake-formats"                 = "iceberg"
    "--conf"                             = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://${aws_s3_bucket.transformation_zone.bucket}/ --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io=org.apache.iceberg.aws.s3.S3FileIO"
  }
}