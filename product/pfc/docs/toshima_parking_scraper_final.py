#!/usr/bin/env python3
"""
豊島区駐輪場情報完全取得スクリプト
各エリアページからすべての駐輪場情報を正確に抽出
"""

import requests
from bs4 import BeautifulSoup
import json
import time
import re
from urllib.parse import urljoin

class ComprehensiveToshimaParkingScraper:
    def __init__(self):
        self.base_url = "https://www.city.toshima.lg.jp"
        self.main_url = "https://www.city.toshima.lg.jp/434/machizukuri/kotsu/churinjo/022247/index.html"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        self.parking_data = []
        self.debug = True

    def log(self, message):
        """デバッグログ出力"""
        if self.debug:
            print(f"[DEBUG] {message}")

    def get_station_links(self):
        """メインページから各駅の駐輪場情報ページのリンクを取得"""
        try:
            response = self.session.get(self.main_url)
            response.raise_for_status()
            soup = BeautifulSoup(response.content, 'html.parser')
            
            station_links = []
            
            # 「区内各駅周辺の駐輪場一覧」のセクションを探す
            main_content = soup.find('div', class_='main-content') or soup.find('div', id='main') or soup
            
            # すべてのaタグをチェック
            for link in main_content.find_all('a', href=True):
                href = link.get('href')
                if href and ('/churinjo/022247/' in href and href.endswith('.html')):
                    full_url = urljoin(self.base_url, href)
                    station_name = link.get_text(strip=True)
                    
                    # リンクが有効で、重複していないかチェック
                    if station_name and full_url not in [item['url'] for item in station_links]:
                        station_links.append({
                            'name': station_name,
                            'url': full_url,
                            'href': href
                        })
                        self.log(f"発見したリンク: {station_name} -> {full_url}")
            
            # 手動で確認済みのリンクも追加（漏れがある場合に備えて）
            known_links = [
                ('池袋駅周辺（東口）', '/434/machizukuri/kotsu/churinjo/022247/022249.html'),
                ('サンシャインシティ周辺', '/434/machizukuri/kotsu/churinjo/022247/022250.html'),
                ('池袋駅周辺（西口）', '/434/machizukuri/kotsu/churinjo/022247/022251.html'),
                ('大塚駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022252.html'),
                ('巣鴨駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022253.html'),
                ('高田馬場駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022254.html'),
                ('目白駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022255.html'),
                ('駒込駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022256.html'),
                ('雑司が谷駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022257.html'),
                ('東池袋駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022258.html'),
                ('要町駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022259.html'),
                ('千川駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022260.html'),
                ('新大塚駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022261.html'),
                ('西巣鴨駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022262.html'),
                ('落合南長崎駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022263.html'),
                ('椎名町駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022264.html'),
                ('東長崎駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022265.html'),
                ('下板橋駅周辺', '/434/machizukuri/kotsu/churinjo/022247/022266.html')
            ]
            
            for name, href in known_links:
                full_url = urljoin(self.base_url, href)
                if full_url not in [item['url'] for item in station_links]:
                    station_links.append({
                        'name': name,
                        'url': full_url,
                        'href': href
                    })
                    self.log(f"手動追加したリンク: {name} -> {full_url}")
            
            print(f"見つかった駅ページ: {len(station_links)}件")
            return station_links
            
        except Exception as e:
            print(f"メインページの取得エラー: {e}")
            return []

    def is_valid_parking_facility(self, name):
        """純粋な駐輪場データかどうかを判定"""
        if not name or len(name.strip()) < 3:
            return False
            
        # 除外すべきキーワード（より厳格に）
        invalid_keywords = [
            '管理課', '管理グループ', '土木管理', '問い合わせ', '連絡先', '事務所',
            '管理人室', '受付所', '案内所', '管理事務所', '管理室',  # 管理人室などを強化
            '各駅の', '放置禁止', '一覧', '写真', '図', '紹介', 'お問い合わせ',
            '窓口', '担当', '部署', '電話：', '利用時間', '定期利用', '料金',
            '円', '区では', '開場', '閉場', '最終電車', '利用状況', '考慮',
            '各施設', '異なって', '運営', '定期購入', '可能', '割引', '詳しく',
            '受付', '抽選', '随時', '原則', '午前', '午後', '前月', '末日',
            '納入', '返還', '注意', '緊急事態宣言', '複数月', '当日利用',
            '回数券', '販売', 'つづり', '共通利用', '登録制', 'ルール',
            '定められた', 'エリア内', 'コイン式', '無料', '民間', '施設',
            '利用料金', '免除', '規定', '対象外', 'ご利用', 'ご注意',
            '指定された', '区画以外', '損害', '賠償', '請求', '破損',
            '盗難', '責任', '降りて', 'ご通行', '管理員', '指示',
            'したがって', '新たに', 'オープン', '変更', '募集', '利用方法',
            'について', 'します', 'した', 'この地域', '撤去', '搬入',
            '隣接', '指定', '活動', '指定管理者', '株式会社', '時間利用',
            'できません', 'ください', 'をもって', '閉鎖', 'をご利用',
            '合わせて', 'あり', 'は、', 'です', 'ます', 'ません'
        ]
        
        # 長すぎる名前は除外（説明文の可能性が高い）
        if len(name) > 50:
            return False
        
        # 無効なキーワードが含まれているかチェック
        for keyword in invalid_keywords:
            if keyword in name:
                return False
        
        # 電話番号のパターンをチェック（これも除外）
        if re.search(r'\d{2,4}-\d{2,4}-\d{4}', name):
            return False
            
        # 数字だけの行は除外
        if re.match(r'^\d+$', name.strip()):
            return False
            
        # 括弧だけで始まる行は除外
        if name.strip().startswith('(') or name.strip().startswith('（'):
            return False
        
        # 駐輪場として有効なキーワード
        valid_keywords = [
            '駐輪場',
            '駐車場', 
            'パーキング',
            'リパーク',
            'エコステーション'
        ]
        
        # 有効なキーワードが含まれているかチェック
        return any(keyword in name for keyword in valid_keywords)

    def extract_facility_info_from_text(self, text_content, station_name):
        """テキストコンテンツから駐輪場情報を抽出"""
        facilities = []
        
        # テキストを行に分割
        lines = [line.strip() for line in text_content.split('\n') if line.strip()]
        
        current_facility = None
        facility_name_patterns = [
            r'.*駐輪場.*',
            r'.*駐車場.*',
            r'.*パーキング.*',
            r'.*リパーク.*',
            r'.*エコステーション.*'
        ]
        
        for line in lines:
            # 駐輪場名の検出
            is_facility_name = any(re.search(pattern, line, re.IGNORECASE) for pattern in facility_name_patterns)
            
            if is_facility_name and len(line) < 100:  # 長すぎる行は除外
                # 純粋な駐輪場データかチェック
                if not self.is_valid_parking_facility(line):
                    continue
                    
                if current_facility and current_facility['name']:
                    facilities.append(current_facility)
                
                current_facility = {
                    'name': line,
                    'station': station_name,
                    'address': '',
                    'phone': '',
                    'hours': '',
                    'fee': '',
                    'subscription': '',
                    'motorbike_support': '',
                    'capacity': '',
                    'other_info': ''
                }
            elif current_facility:
                # 住所の検出
                if ('区' in line or '町' in line or '丁目' in line) and len(line) < 100:
                    if not current_facility['address']:
                        current_facility['address'] = line
                
                # 電話番号の検出
                phone_match = re.search(r'\d{2,4}-\d{2,4}-\d{4}', line)
                if phone_match:
                    current_facility['phone'] = phone_match.group()
                
                # 利用時間の検出
                if ('時間' in line or '午前' in line or '午後' in line or '24時間' in line) and '円' not in line:
                    if not current_facility['hours']:
                        current_facility['hours'] = line
                
                # 料金の検出
                if '円' in line and ('時間' in line or '料金' in line or '無料' in line):
                    if not current_facility['fee']:
                        current_facility['fee'] = line
                
                # 収容台数の検出
                capacity_match = re.search(r'(\d+)\s*台', line)
                if capacity_match:
                    current_facility['capacity'] = capacity_match.group()
                
                # 原付対応の検出
                if '原付' in line or 'バイク' in line:
                    current_facility['motorbike_support'] = line
                
                # 定期利用の検出
                if '定期' in line or '月極' in line:
                    if not current_facility['subscription']:
                        current_facility['subscription'] = line
        
        # 最後の施設を追加
        if current_facility and current_facility['name']:
            facilities.append(current_facility)
        
        return facilities

    def extract_table_data(self, soup, station_name):
        """テーブルからデータを抽出"""
        facilities = []
        tables = soup.find_all('table')
        
        for table in tables:
            rows = table.find_all('tr')
            if len(rows) < 2:
                continue
            
            # テーブルのヘッダーを確認
            headers = []
            if rows:
                header_cells = rows[0].find_all(['th', 'td'])
                headers = [cell.get_text(strip=True) for cell in header_cells]
            
            # 駐輪場関連のテーブルかチェック
            is_parking_table = any(keyword in ' '.join(headers) for keyword in ['駐輪', '名称', '住所', '電話', '料金', '台数'])
            
            if is_parking_table:
                for row in rows[1:]:
                    cells = row.find_all(['td', 'th'])
                    if len(cells) >= 2:
                        cell_texts = [cell.get_text(strip=True) for cell in cells]
                        
                        facility = {
                            'name': '',
                            'station': station_name,
                            'address': '',
                            'phone': '',
                            'hours': '',
                            'fee': '',
                            'subscription': '',
                            'motorbike_support': '',
                            'capacity': '',
                            'other_info': ''
                        }
                        
                        # セルの内容を分析
                        for i, text in enumerate(cell_texts):
                            if i == 0 and self.is_valid_parking_facility(text):
                                facility['name'] = text
                            elif '区' in text or '町' in text or '丁目' in text:
                                if not facility['address']:
                                    facility['address'] = text
                            elif re.search(r'\d{2,4}-\d{2,4}-\d{4}', text):
                                if not facility['phone']:
                                    facility['phone'] = text
                            elif ('時' in text or '24時間' in text) and '円' not in text:
                                if not facility['hours']:
                                    facility['hours'] = text
                            elif '円' in text:
                                if not facility['fee']:
                                    facility['fee'] = text
                            elif re.search(r'\d+\s*台', text):
                                if not facility['capacity']:
                                    facility['capacity'] = text
                        
                        if facility['name']:
                            facilities.append(facility)
        
        return facilities

    def extract_address_from_text(self, text):
        """テキストから住所情報を抽出（改善版）"""
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        
        for line in lines:
            # 住所のプレフィックスを削除
            clean_line = line.replace('住所：', '').replace('住所:', '').strip()
            
            # 明確に除外すべきパターン
            invalid_patterns = [
                r'交通案内',
                r'JR.*駅',
                r'メトロ.*駅',
                r'西武線',
                r'改札より',
                r'出口',
                r'直結',
                r'約\d+メートル',
                r'令和\d+年',
                r'閉鎖',
                r'をもって',
                r'写真街区',
                r'Dエリア',
                r'地下',
                r'[東西南北]口',
                r'エレベーター',
                r'階段',
                r'電話',
                r'TEL',
                r'営業時間',
                r'利用時間',
                r'料金',
                r'円',
                r'台',
                r'利用可',
                r'利用不可',
                r'原付',
                r'バイク',
                r'定期',
                r'月極'
            ]
            
            # 無効パターンがあるかチェック
            if any(re.search(pattern, clean_line) for pattern in invalid_patterns):
                continue
            
            # 有効な住所パターン（より柔軟に）
            address_patterns = [
                r'.*[区市].*[町村].*\d+.*',  # 区・町・番号
                r'.*[区市].*\d+-\d+.*',      # 区・番号-番号
                r'.*[区市].*\d+先.*',        # 区・番号先
                r'.*[区市].*\d+丁目.*',      # 区・丁目
                r'.*池袋\d+-\d+-\d+',        # 池袋の番号パターン（3桁）
                r'.*大塚\d+-\d+-\d+',        # 大塚の番号パターン（3桁）
                r'.*巣鴨\d+-\d+-\d+',        # 巣鴨の番号パターン（3桁）
                r'.*要町\d+-\d+-\d+',        # 要町の番号パターン（3桁）
                r'.*巣鴨\d+-\d+$',           # 巣鴨の番号パターン（2桁）
                r'.*目白\d+-\d+$',           # 目白の番号パターン（2桁）
                r'.*駒込\d+-\d+$',           # 駒込の番号パターン（2桁）
                r'.*雑司が谷\d+-\d+$',       # 雑司が谷の番号パターン（2桁）
                r'.*千川\d+-\d+$',           # 千川の番号パターン（2桁）
                r'.*町\d+.*',                # 町番号
                r'.*\d+先.*',                # 番号先
                r'.*\d+-\d+.*先.*',          # 番号-番号先
                r'.*\d+丁目\d+.*',           # 丁目番号
                r'.*[一二三四五六七八九]丁目.*',  # 漢数字丁目
                r'.*\d+-\d+-\d+',            # 番号-番号-番号（一般的な住所）
                r'.*[東西南北]池袋.*\d+.*'    # 東池袋、西池袋などのパターン
            ]
            
            # 住所として有効で、3文字以上50文字以下
            if (any(re.search(pattern, clean_line) for pattern in address_patterns) and 
                3 <= len(clean_line) <= 50):
                return clean_line
        
        return ''

    def extract_structured_data(self, soup, station_name):
        """HTMLの構造化データから駐輪場情報を抽出"""
        facilities = []
        
        # h3タグで区切られた駐輪場セクションを探す
        h3_tags = soup.find_all('h3')
        
        for h3 in h3_tags:
            facility_name = h3.get_text(strip=True)
            
            # 駐輪場名として有効かチェック
            if not self.is_valid_parking_facility(facility_name):
                continue
                
            facility = {
                'name': facility_name,
                'station': station_name,
                'address': '',
                'phone': '',
                'hours': '',
                'fee': '',
                'subscription': '',
                'motorbike_support': '',
                'capacity': '',
                'other_info': ''
            }
            
            # h3の次の要素を探す（div、p、ul、tableなど）
            current_element = h3.find_next_sibling()
            content_texts = []
            
            while current_element and current_element.name in ['p', 'ul', 'table', 'div']:
                element_text = current_element.get_text()
                content_texts.append(element_text)
                
                if current_element.name == 'p':
                    # 住所と電話番号を抽出
                    lines = [line.strip() for line in element_text.split('\n') if line.strip()]
                    
                    for line in lines:
                        # 住所抽出（改善版）
                        if not facility['address']:
                            address = self.extract_address_from_text(line)
                            if address:
                                facility['address'] = address
                        
                        # 電話番号を抽出
                        phone_match = re.search(r'電話[：:]?\s*(\d{2,4}-\d{2,4}-\d{4})', line)
                        if phone_match:
                            facility['phone'] = phone_match.group(1)
                
                elif current_element.name == 'ul':
                    # リスト形式の情報を抽出
                    list_items = current_element.find_all('li')
                    for li in list_items:
                        li_text = li.get_text(strip=True)
                        
                        # 住所抽出（改善版）
                        if not facility['address']:
                            address = self.extract_address_from_text(li_text)
                            if address:
                                facility['address'] = address
                        
                        # 電話番号
                        phone_match = re.search(r'電話[：:]?\s*(\d{2,4}-\d{2,4}-\d{4})', li_text)
                        if phone_match:
                            facility['phone'] = phone_match.group(1)
                        
                        # 利用時間
                        if ('時間' in li_text or '午前' in li_text or '午後' in li_text or '24時間' in li_text) and '円' not in li_text:
                            if not facility['hours']:
                                facility['hours'] = li_text
                        
                        # 料金
                        if '円' in li_text:
                            if not facility['fee']:
                                facility['fee'] = li_text
                        
                        # 収容台数
                        capacity_match = re.search(r'(\d+)台', li_text)
                        if capacity_match:
                            facility['capacity'] = capacity_match.group()
                        
                        # 原付対応
                        if '原付' in li_text:
                            if '利用できません' in li_text or '利用不可' in li_text:
                                facility['motorbike_support'] = '利用不可'
                            elif '円' in li_text or '利用可' in li_text:
                                facility['motorbike_support'] = '利用可能'
                
                elif current_element.name == 'table':
                    # テーブル形式の情報を抽出
                    # 料金情報の抽出（円を含む行から）
                    fee_lines = []
                    for line in element_text.split('\n'):
                        line = line.strip()
                        if '円' in line and len(line) < 100:
                            fee_lines.append(line)
                    
                    if fee_lines and not facility['fee']:
                        # 最も具体的な料金情報を選択
                        for fee_line in fee_lines:
                            if '時間' in fee_line or '無料' in fee_line:
                                facility['fee'] = fee_line
                                break
                        if not facility['fee'] and fee_lines:
                            facility['fee'] = fee_lines[0]
                    
                    # 利用時間の抽出
                    if '24時間' in element_text and not facility['hours']:
                        facility['hours'] = '24時間'
                    elif ('午前' in element_text or '午後' in element_text) and not facility['hours']:
                        time_match = re.search(r'午前\d+時.*?午後\d+時.*?\d+分', element_text)
                        if time_match:
                            facility['hours'] = time_match.group()
                    
                    # 原付対応の判定
                    if '原付' in element_text and not facility['motorbike_support']:
                        if '利用できません' in element_text or '利用不可' in element_text:
                            facility['motorbike_support'] = '利用不可'
                        elif '円' in element_text and '原付' in element_text:
                            facility['motorbike_support'] = '利用可能'
                
                # 次の要素へ
                current_element = current_element.find_next_sibling()
                
                # 次のh3タグが来たら終了
                if current_element and current_element.name == 'h3':
                    break
            
            # 住所がまだ見つからない場合は、すべてのコンテンツから検索
            if not facility['address'] and content_texts:
                all_text = ' '.join(content_texts)
                address = self.extract_address_from_text(all_text)
                if address:
                    facility['address'] = address
            
            # 最低限の情報（名前）があれば追加
            if facility['name'] and len(facility['name']) > 3:
                facilities.append(facility)
                self.log(f"抽出成功: {facility['name']} - {facility['address']}")
        
        return facilities

    def extract_parking_info(self, station_name, station_url):
        """各駅のページから駐輪場情報を抽出"""
        try:
            self.log(f"{station_name}のページを取得: {station_url}")
            response = self.session.get(station_url)
            response.raise_for_status()
            soup = BeautifulSoup(response.content, 'html.parser')
            
            facilities = []
            
            # HTML構造化データから抽出（メイン手法）
            facilities = self.extract_structured_data(soup, station_name)
            self.log(f"構造化データから{len(facilities)}件抽出")
            
            # 住所が見つからない駐輪場について、ページ全体から住所を検索
            page_text = soup.get_text()
            for facility in facilities:
                if not facility['address']:
                    # 駐輪場名の前後から住所を検索
                    name_pattern = re.escape(facility['name'])
                    # 駐輪場名の後に続く文章から住所を抽出
                    match = re.search(name_pattern + r'[^\n]*?\n([^\n]*)', page_text)
                    if match:
                        potential_address = self.extract_address_from_text(match.group(1))
                        if potential_address:
                            facility['address'] = potential_address
                            self.log(f"ページ全体から住所発見: {facility['name']} - {potential_address}")
            
            # データをJSON形式に整形（必要な情報のみ）
            cleaned_facilities = []
            for facility in facilities:
                # 住所のクリーニング（更に改善）
                address = facility['address']
                if address:
                    # 最終的なクリーニング（既に extract_address_from_text で処理済みだが念のため）
                    address = address.replace('住所：', '').replace('住所:', '').strip()
                    
                    # 追加の除外チェック
                    invalid_address_keywords = [
                        '交通案内', 'JR', 'メトロ', '西武線', '改札より', '出口', '直結',
                        '令和', '閉鎖', 'をもって', '写真街区', 'Dエリア',
                        '約', 'メートル', '地下', '北口', '南口', '東口', '西口',
                        'エレベーター', '階段', '電話', 'TEL', '円', '台',
                        '営業時間', '利用時間', '料金', '原付', 'バイク'
                    ]
                    
                    if any(keyword in address for keyword in invalid_address_keywords):
                        address = ''
                    
                    # 空文字や短すぎる住所は除外
                    if len(address) < 3:
                        address = ''
                
                cleaned_facility = {
                    '駐輪場名': facility['name'],
                    '住所': address,
                    '電話番号': facility['phone'],
                    '利用時間': facility['hours'],
                    '料金': facility['fee'],
                    '原付対応': facility['motorbike_support'],
                    '収容台数': facility['capacity']
                }
                cleaned_facilities.append(cleaned_facility)
            
            print(f"{station_name}: {len(cleaned_facilities)}件の駐輪場情報を取得")
            return cleaned_facilities
            
        except Exception as e:
            print(f"{station_name}の情報取得エラー: {e}")
            return []

    def scrape_all(self):
        """全ての駐輪場情報を取得"""
        print("豊島区駐輪場情報の完全取得を開始します...")
        
        # 各駅のリンクを取得
        station_links = self.get_station_links()
        
        if not station_links:
            print("駅のリンクが見つかりませんでした")
            return
        
        # 各駅の情報を取得
        for i, station in enumerate(station_links):
            print(f"\n[{i+1}/{len(station_links)}] {station['name']}の情報を取得中...")
            facilities = self.extract_parking_info(station['name'], station['url'])
            self.parking_data.extend(facilities)
            
            # サーバーに負荷をかけないように少し待機
            time.sleep(1)
        
        print(f"\n完了！合計 {len(self.parking_data)}件の駐輪場情報を取得しました")

    def save_to_json(self, filename='complete_toshima_parking_data.json'):
        """取得したデータをJSONファイルに保存"""
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(self.parking_data, f, ensure_ascii=False, indent=2)
            print(f"データを{filename}に保存しました")
        except Exception as e:
            print(f"ファイル保存エラー: {e}")

    def save_to_csv(self, filename='complete_toshima_parking_data.csv'):
        """取得したデータをCSVファイルに保存"""
        try:
            import pandas as pd
            if self.parking_data:
                df = pd.DataFrame(self.parking_data)
                df.to_csv(filename, index=False, encoding='utf-8-sig')
                print(f"データを{filename}に保存しました")
        except ImportError:
            print("CSVファイル保存にはpandasが必要です: pip install pandas")
        except Exception as e:
            print(f"CSV保存エラー: {e}")

    def print_summary(self):
        """取得したデータの概要を表示"""
        if not self.parking_data:
            print("取得したデータがありません")
            return
        
        print("\n" + "="*50)
        print("取得データの概要")
        print("="*50)

def main():
    scraper = ComprehensiveToshimaParkingScraper()
    scraper.scrape_all()
    scraper.print_summary()
    scraper.save_to_json()
    # scraper.save_to_csv()  # CSVも必要な場合はコメントアウト

if __name__ == "__main__":
    main()