from selenium import webdriver
from selenium.webdriver.common.by import By
from bs4 import BeautifulSoup
from tempfile import mkdtemp

import time
import datetime
import boto3

# TokyoGasログインページを起動
service = webdriver.ChromeService("/opt/chromedriver")
options = webdriver.ChromeOptions()

options.binary_location = '/opt/chrome/chrome'
options.add_argument("--headless=new")
options.add_argument('--no-sandbox')
options.add_argument("--disable-gpu")
options.add_argument("--window-size=1280x1696")
options.add_argument("--single-process")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--disable-dev-tools")
options.add_argument("--no-zygote")
options.add_argument(f"--user-data-dir={mkdtemp()}")
options.add_argument(f"--data-path={mkdtemp()}")
options.add_argument(f"--disk-cache-dir={mkdtemp()}")
options.add_argument("--remote-debugging-port=9222")

chrome = webdriver.Chrome(options=options, service=service)

 try:

chrome.get('https://members.tokyo-gas.co.jp/login.html')
time.sleep(10)



# NAME属性が”identity”であるHTML要素を取得し、ログインID文字列をキーボード送信
chrome.find_element(By.NAME,"loginId").send_keys("")
# NAME属性が”password”であるHTML要素を取得し、パスワード文字列をキーボード送信
chrome.find_element(By.NAME,"password").send_keys("")
# CLASS属性が”sessions_button--wide”であるHTML要素を取得してクリック
chrome.find_element(By.ID,"submit-btn").click()

time.sleep(5)

# 電気使用量のページに移動
chrome.get('https://members.tokyo-gas.co.jp/usage?tab=electricity')
time.sleep(5)
chrome.find_element(By.ID,"segmented-button-daily").click()

time.sleep(5)

# 昨日の電気使用量を取得
daily = chrome.find_element(By.XPATH,'//*[@id="mtg-karte-electricity"]/div/div/div[2]/div/div[1]/div[2]/div[2]/div/div[1]/div').text

# 昨日の電気使用量を出力
print(daily)

# Webドライバー の セッションを終了
chrome.quit()

# 今日の日付を取得して年月を取り出す
today = datetime.datetime.now()
year_month = today.strftime("%Y%m")
day = today.strftime("%d")
key = f'{year_month}/{day}.txt'

# S3 への保存
s3 = boto3.client('s3')
s3.put_object(Bucket='tokyo-gas-electricity', Key=key, Body=daily)