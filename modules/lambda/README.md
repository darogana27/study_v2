function_name
filename(or image_uri)
は必須項目です

↓以下例

module "lambda_function" {
  source = "../modules/lambda"
  function_name = "test"
  filename = "./lambda/Line_Notify.zip"
}