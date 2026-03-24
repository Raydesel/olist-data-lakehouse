import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, to_timestamp

# ==========================================
# 1. INITIALIZE SPARK & GLUE
# ==========================================
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# ==========================================
# 2. CONFIGURATION (⚠️ UPDATE THIS!)
# ==========================================
# Look at your Terraform output and replace '4adb3345' with your actual bucket suffix
LANDING_ZONE = "s3://olist-landing-zone-4adb3345/raw/"
CATALOG_DB = "olist_lakehouse_db"

# ==========================================
# 3. BASE DIMENSION DATA
# ==========================================
print("Processing customers...")
df_customers = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{LANDING_ZONE}olist_customers_dataset.csv")
df_customers.dropDuplicates(["customer_unique_id"]).writeTo(f"glue_catalog.{CATALOG_DB}.base_customers").tableProperty("format-version", "2").createOrReplace()

print("Processing products...")
df_products = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{LANDING_ZONE}olist_products_dataset.csv")
df_products.writeTo(f"glue_catalog.{CATALOG_DB}.base_products").tableProperty("format-version", "2").createOrReplace()

print("Processing product translations...")
df_translations = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{LANDING_ZONE}product_category_name_translation.csv")
df_translations.writeTo(f"glue_catalog.{CATALOG_DB}.base_translations").tableProperty("format-version", "2").createOrReplace()

print("Processing sellers...")
df_sellers = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{LANDING_ZONE}olist_sellers_dataset.csv")
df_sellers.writeTo(f"glue_catalog.{CATALOG_DB}.base_sellers").tableProperty("format-version", "2").createOrReplace()

print("Processing geolocation...")
df_geo = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{LANDING_ZONE}olist_geolocation_dataset.csv")
df_geo.dropDuplicates(["geolocation_zip_code_prefix"]).writeTo(f"glue_catalog.{CATALOG_DB}.base_geolocation").tableProperty("format-version", "2").createOrReplace()

# ==========================================
# 4. BASE FACT DATA
# ==========================================
print("Processing orders (Needed for purchase dates!)...")
df_orders = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{LANDING_ZONE}olist_orders_dataset.csv")
df_orders.withColumn("order_purchase_timestamp", to_timestamp(col("order_purchase_timestamp"))) \
    .sortWithinPartitions("order_status") \
    .writeTo(f"glue_catalog.{CATALOG_DB}.base_orders") \
    .tableProperty("format-version", "2") \
    .partitionedBy("order_status").createOrReplace()

print("Processing order items...")
df_items = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{LANDING_ZONE}olist_order_items_dataset.csv")
df_items.withColumn("shipping_limit_date", to_timestamp(col("shipping_limit_date"))) \
    .writeTo(f"glue_catalog.{CATALOG_DB}.base_order_items") \
    .tableProperty("format-version", "2").createOrReplace()

print("✅ Base Tables for Star Schema Created Successfully!")
job.commit()