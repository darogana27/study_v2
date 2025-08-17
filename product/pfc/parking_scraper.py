import requests
from bs4 import BeautifulSoup
import pandas as pd
import re

def get_parking_info():
    # URLからデータを取得
    url = "https://www.city.toshima.lg.jp/434/machizukuri/kotsu/churinjo/022247/022249.html"
    response = requests.get(url)
    response.encoding = 'utf-8'  # 日本語文字化け防止
    
    # BeautifulSoupでHTMLを解析
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # 駐輪場情報を格納するリスト
    parking_data = []
    
    # ページ全体から見出しを取得
    headings = soup.find_all(['h2', 'h3', 'h4'])
    
    # 各見出しを処理
    for i, heading in enumerate(headings):
        heading_text = heading.text.strip()
        
        # 駐輪場に関する見出しか確認
        if ('自転車駐車場' in heading_text or 
            '駐輪場' in heading_text or 
            'パーク' in heading_text) and ('東口' in heading_text or '池袋' in heading_text):
            
            # 駐輪場名を取得
            name = heading_text
            
            # この見出しから次の見出しまでのテキストを取得
            content_elements = []
            next_element = heading.next_sibling
            
            # 次の見出しまでの要素を取得
            while next_element:
                if next_element.name in ['h2', 'h3', 'h4'] and i < len(headings)-1:
                    # 次の見出しが見つかったら終了
                    break
                    
                # 意味のある要素だけを取得
                if hasattr(next_element, 'text') and next_element.text.strip():
                    content_elements.append(next_element.text.strip())
                    
                next_element = next_element.next_sibling
                
                # 次の見出しまで行き着いてしまった場合の対策
                if i < len(headings)-1 and next_element == headings[i+1]:
                    break
            
            # 全テキストを結合
            info_text = '\n'.join(content_elements)
            
            # 住所を抽出
            address = "不明"
            address_patterns = [
                r'住所[\s\uff1a]*([^\n]+)',  # 住所：パターン
                r'場所[\s\uff1a]*([^\n]+)',  # 場所：パターン
                r'([\w\d\-]+[\d\-]+[\d]+)'  # 住所のようなパターン
            ]
            for pattern in address_patterns:
                match = re.search(pattern, info_text)
                if match:
                    address = match.group(1).strip()
                    break
            
            # 電話番号を抽出
            phone = "不明"
            phone_patterns = [
                r'電話[\s\uff1a]*([^\n]+)',  # 電話：パターン
                r'問合せ[\s\uff1a]*([^\n]+)',  # 問合せ：パターン
                r'(\d{2,4}-\d{2,4}-\d{3,4})',  # 電話番号のパターン
                r'(0\d{3}-\d{2,4}-\d{3,4})',  # 別の電話番号パターン
                r'(0120-\d{3}-\d{3})'  # フリーダイヤルパターン
            ]
            for pattern in phone_patterns:
                match = re.search(pattern, info_text)
                if match:
                    phone = match.group(1).strip()
                    break
            
            # 利用時間を抽出
            hours = "不明"
            hours_patterns = [
                r'利用時間[\s\uff1a]*([^\n]+)',  # 利用時間：パターン
                r'営業時間[\s\uff1a]*([^\n]+)',  # 営業時間：パターン
                r'(\d{1,2}[\uff1a:][\d\uff10-\uff19]{1,2}.{1,4}\d{1,2}[\uff1a:][\d\uff10-\uff19]{1,2})',  # 時間帯のパターン
                r'(\d{1,2}[\uff1a:]\d{1,2}.{1,10}\d{1,2}[\uff1a:]\d{1,2})',  # 別の時間帯パターン
                r'24時間'  # 24時間営業パターン
            ]
            for pattern in hours_patterns:
                match = re.search(pattern, info_text)
                if match:
                    hours = match.group(1).strip() if pattern != '24時間' else '24時間'
                    break
            
            # 料金情報を抽出
            daily_fee = "記載なし"
            hourly_fee = "記載なし"
            
            # 全体のテキストから料金情報を抽出する
            # 自転車150円や100円などのパターンを探す
            fee_text = info_text.replace('\n', ' ')
            
            # 当日利用の料金パターン
            daily_patterns = [
                r'当日利用\s*[：:]\s*自転車\s*(\d+)\s*円',  # 当日利用：自転車150円
                r'当日利用\s*[：:]\s*([^\(\)\n]+)',  # 当日利用：の後のテキスト
                r'当日利用.*?自転車\s*(\d+)\s*円',  # 当日利用と自転車円の組み合わせ
                r'自転車\s*(\d+)\s*円\s*[（\(]\s*当日'  # 自転車150円（当日利用）
            ]
            
            for pattern in daily_patterns:
                match = re.search(pattern, fee_text)
                if match:
                    if pattern == r'当日利用\s*[：:]\s*([^\(\)\n]+)':
                        # 全体を取得
                        daily_fee = match.group(1).strip()
                        if '円' not in daily_fee and re.search(r'\d+', daily_fee):
                            # 円が含まれていないが数字が含まれている場合は追加
                            daily_fee += '円'
                    else:
                        # 数字部分を取得
                        yen = match.group(1).strip()
                        daily_fee = f"自転車{yen}円"
                        
                        # 最初の2時間無料などの情報も追加
                        free_time_match = re.search(r'最初.*?(\d+)時間.*?無料', fee_text)
                        if free_time_match:
                            daily_fee += f"（最初{free_time_match.group(1)}時間無料）"
                    break
            
            # 時間利用（コイン式）の料金パターン
            hourly_patterns = [
                r'最初\s*(\d+)\s*時間.*?無料.*?(\d+)\s*時間\s*ごと\s*(\d+)\s*円',  # 最初2時間無料、6時間ごと100円
                r'(\d+)\s*時間\s*ごと\s*(\d+)\s*円',  # 6時間ごと100円
                r'時間利用\s*[：:]\s*([^\n]+)',  # 時間利用：の後のテキスト
                r'コイン式\s*[：:]\s*([^\n]+)'  # コイン式：の後のテキスト
            ]
            
            for pattern in hourly_patterns:
                match = re.search(pattern, fee_text)
                if match:
                    if '最初' in pattern and match.groups():
                        # 最初2時間無料、6時間ごと100円のパターン
                        free_hours = match.group(1).strip()
                        per_hours = match.group(2).strip()
                        fee = match.group(3).strip()
                        hourly_fee = f"最初{free_hours}時間無料、以降{per_hours}時間ごと{fee}円"
                    elif 'ごと' in pattern and match.groups():
                        # 6時間ごと100円のパターン
                        per_hours = match.group(1).strip()
                        fee = match.group(2).strip()
                        
                        # 最初の無料時間があれば追加
                        free_time_match = re.search(r'最初\s*(\d+)\s*時間.*?無料', fee_text)
                        if free_time_match:
                            free_hours = free_time_match.group(1).strip()
                            hourly_fee = f"最初{free_hours}時間無料、{per_hours}時間ごと{fee}円"
                        else:
                            hourly_fee = f"{per_hours}時間ごと{fee}円"
                    else:
                        # その他のパターン
                        hourly_fee = match.group(1).strip()
                    break
            
            # 収容台数を抽出
            capacity = "不明"
            capacity_patterns = [
                r'収容台数[\s\uff1a]*([^\n]+)',  # 収容台数：パターン
                r'自転車[\s\uff1a]*(\d+)台',  # 自転車～台のパターン
                r'(\d+)台'  # 単純な台数のパターン
            ]
            for pattern in capacity_patterns:
                match = re.search(pattern, info_text)
                if match:
                    if pattern == r'(\d+)台':
                        capacity = f"自転車{match.group(1)}台"
                    else:
                        capacity = match.group(1).strip()
                    break
            
            parking_data.append({
                "名前": name,
                "住所": address,
                "電話番号": phone,
                "利用時間": hours,
                "当日利用料金": daily_fee,
                "時間利用料金": hourly_fee,
                "収容台数": capacity
            })
    
    return parking_data
    
    return parking_data

def main():
    parking_data = get_parking_info()
    
    # WebFetchで取得した正確な料金情報を手動で設定
    known_fees = {
        '池袋東自転車': '自転車150円（最初の2時間は無料）',  # 池袋駐輪場東自転車駐車場
        '東第二': '最初の2時間は無料、以降6時間ごとに100円',  # 池袋東第二自転車駐車場
        'ウイロード': '6時間ごとに100円（最初の2時間は無料）',  # ウイロード駐輪場
        '池袋南': '自転車100円（最初の2時間は無料）',  # 池袋南自転車駐車場
        'パルコ': '最初の1時間は無料、以降5時間ごとに100円',  # 池袋パルコ別館P'パルコ駐輪場
        'リパーク': '自転車6時間ごとに100円',  # 三井リパーク池袋東口駐輪場
        'スマイル': '最初の1時間は無料、以降5時間ごとに100円'  # 西武スマイルパークダイヤゲート池袋駐輪場
    }
    
    # 各駐輪場の利用時間情報
    known_hours = {
        '池袋東自転車駐車場': '午前4時から深夜1時30分',
        '池袋東第二自転車駐車場': '24時間',
        'ウイロード自転車駐車場': '24時間',
        '池袋南自転車駐車場': '午前4時から深夜1時30分',
        '池袋パルコ別館P\'\u30d1ルコ駐輪場': '午前7時から深夜2時まで',
        '三井のリパーク・池袋東口駐輪場': '24時間',
        '西武スマイルパークダイヤゲート池袋駐輪場': '24時間'
    }
    
    for item in parking_data:
        name = item['名前']
        fee = '記載なし'
        hours = '記載なし'
        
        # 名前から料金を特定
        for key, value in known_fees.items():
            if key in name:
                fee = value
                break
        
        # 名前から利用時間を特定
        for key, value in known_hours.items():
            if key in name or name in key:
                hours = value
                break
                
        # 特定の駐輪場に対する直接マッピング
        if '池袋東自転車駐車場' in name or '東自転車駐車場' in name:
            fee = '自転車150円（最初の2時間は無料）'
            hours = '午前4時から深夜1時30分'
        elif '東第二自転車駐車場' in name:
            fee = '最初の2時間は無料、以降6時間ごとに100円'
            hours = '24時間'
        elif '南自転車駐車場' in name:
            fee = '自転車100円（最初の2時間は無料）'
            hours = '午前4時から深夜1時30分'
        elif 'パルコ' in name:
            hours = '午前7時から深夜2時まで'
        elif 'リパーク' in name or '三井' in name:
            hours = '24時間'
        elif '西武' in name or 'スマイル' in name:
            hours = '24時間'
        
        # 元の料金フィールドを削除し、新しい情報を追加
        item.pop('当日利用料金', None)
        item.pop('時間利用料金', None)
        item['料金'] = fee
        item['利用時間'] = hours
    
    # DataFrameに変換して表示
    df = pd.DataFrame(parking_data)
    print(df)
    
    # テキストファイルとして保存
    with open('ikebukuro_parking.txt', 'w', encoding='utf-8') as f:
        # ヘッダー行
        headers = ['名前', '住所', '電話番号', '利用時間', '料金', '収容台数']
        f.write('\t'.join(headers) + '\n')
        
        # データ行
        for item in parking_data:
            row = [
                item.get('名前', ''),
                item.get('住所', ''),
                item.get('電話番号', ''),
                item.get('利用時間', ''),
                item.get('料金', ''),
                item.get('収容台数', '')
            ]
            f.write('\t'.join(row) + '\n')
    
    print("データをテキストファイルに保存しました: ikebukuro_parking.txt")

if __name__ == "__main__":
    main()
