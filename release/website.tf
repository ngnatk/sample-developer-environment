# Sample index.html file for website
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = <<EOF
<html>
<body>
<h1>Hello from Terraform!</h1>
<p>If you see this, your pipeline is working.</p>
<p>Deployed at: ${timestamp()}</p>
</body>
</html>
EOF
  content_type = "text/html"
}