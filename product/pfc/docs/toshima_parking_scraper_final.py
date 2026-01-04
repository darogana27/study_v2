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
                            elif ('時' in text or '24時間' in text or '深夜' in text) and '円' not in text and '台' not in text:
                                # 時間関連の不要なキーワードを除外
                                invalid_time_keywords = ['営業時間', '受付時間', '問い合わせ時間', '連絡時間']
                                if not any(keyword in text for keyword in invalid_time_keywords):
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

    def clean_text_content(self, text):
        """テキストから改行・タブを除去してクリーンアップ"""
        if not text:
            return ''
        # 改行とタブを空白に置換
        cleaned = text.replace('\n', ' ').replace('\t', ' ')
        # 連続する空白を単一の空白に
        import re
        cleaned = re.sub(r'\s+', ' ', cleaned)
        return cleaned.strip()

    def extract_coin_fee_info(self, content_text):
        """コイン式（当日利用）料金のみを抽出"""
        fee_parts = []
        
        # 当日利用が「なし」の場合は定期利用のみ
        if 'なし' in content_text and '当日利用' in content_text:
            return '定期利用のみ'
        
        # 定期利用料金を示すキーワード（これらを除外）
        periodic_keywords = [
            '一般', '学生', 'ヶ月', 'か月', '月額', '定期利用', '定期',
            '年間', '学生証', '身体障害者手帳', '愛の手帳', '区内居住者', '区外居住者',
            '4,500円', '3,000円', '2,500円', '1,250円', '1,500円', '2,100円', '1,400円'
        ]
        
        # コイン式料金パターン（より包括的に）
        coin_patterns = [
            r'最初の\d+時間は?無料[、，、\s]*以降\d+時間ごとに\d+円',
            r'最初の\d+時間無料[、，、\s]*以降\d+時間ごとに\d+円',
            r'\d+時間まで無料[、，、\s]*以降\d+時間ごとに\d+円',
            r'自転車\d+円[（(]最初の\d+時間は?無料[）)]',
            r'自転車：?\s*\d+円[（(]最初の\d+時間は?無料[）)]',
            r'自転車：?\s*\d+円',
            r'\d+時間ごとに\d+円',
            r'\d+時間\d+円',
            r'\d+分\d+円',
            r'以降\d+時間ごとに\d+円',
            r'自転車\s*\d+円',
            r'コイン式.*?\d+円',
            r'時間利用.*?\d+円'
        ]
        
        # 特別な複合パターン（池袋駅東第二のような「最初2時間無料+以降6時間ごとに100円」）
        complex_patterns = [
            r'最初の\d+時間は?無料.*?以降\d+時間ごとに\d+円',
            r'最初の\d+時間無料.*?以降\d+時間ごとに\d+円'
        ]
        
        # 複合パターンを先にチェック
        for pattern in complex_patterns:
            match = re.search(pattern, content_text)
            if match:
                cleaned_match = self.clean_text_content(match.group())
                # 定期利用料金を除外（キーワードベース + 高額料金判定）
                is_periodic = any(keyword in cleaned_match for keyword in periodic_keywords)
                has_high_amount = re.search(r'[1-9]\d{3,}円', cleaned_match)
                if not is_periodic and not has_high_amount:
                    fee_parts.append(cleaned_match)
                    break  # 複合パターンが見つかったら単一パターンは処理しない
        
        # 複合パターンが見つからなかった場合は単一パターンを処理
        if not fee_parts:
            for pattern in coin_patterns:
                matches = re.findall(pattern, content_text)
                for match in matches:
                    cleaned_match = self.clean_text_content(match)
                    # 定期利用料金を除外（キーワードベース + 高額料金判定）
                    is_periodic = any(keyword in cleaned_match for keyword in periodic_keywords)
                    # 1000円以上の料金は定期利用の可能性が高い（時間料金は通常100円単位）
                    has_high_amount = re.search(r'[1-9]\d{3,}円', cleaned_match)
                    if not is_periodic and not has_high_amount and cleaned_match not in fee_parts:
                        fee_parts.append(cleaned_match)
        
        return '、'.join(fee_parts) if fee_parts else ''

    def extract_operating_hours(self, content_text):
        """利用時間を正確に抽出"""
        # 24時間営業の明確な指定
        if '24時間' in content_text:
            return '24時間'
        
        # 具体的な時間表記を探す
        time_patterns = [
            r'午前\d+時から[深夜午後]*\d+時\d*分?',
            r'午前\d+時.*?から.*?[深夜午後].*?時.*?\d*分?',
            r'\d+時から\d+時'
        ]
        
        for pattern in time_patterns:
            time_match = re.search(pattern, content_text)
            if time_match:
                cleaned_hours = self.clean_text_content(time_match.group())
                if cleaned_hours and '円' not in cleaned_hours and '台' not in cleaned_hours:
                    return cleaned_hours
        
        # 当日利用がある場合の営業時間
        if '当日利用' in content_text and 'なし' not in content_text:
            return '当日利用可能'
        
        return ''

    def determine_motorbike_support(self, content_text, capacity_text):
        """原付対応を自動判定"""
        # 明示的な記載がある場合
        if '原付' in content_text:
            if '利用できません' in content_text or '利用不可' in content_text:
                return '利用不可'
            elif '利用できます' in content_text or '利用可能' in content_text:
                return '利用可能'
        
        # 収容台数にバイクや原付の文字が含まれていない場合は利用不可
        if capacity_text and not re.search(r'[バイク原付]', capacity_text):
            return '利用不可'
        
        return ''

    def extract_structured_data(self, soup, station_name):
        """HTMLの構造化データから駐輪場情報を抽出（完全版）"""
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
            
            # h3の次の要素を広範囲に探す（改善版）
            current_element = h3.find_next_sibling()
            content_texts = []
            all_element_text = ""
            
            # セクション全体のテキストを収集
            while current_element and current_element.name in ['p', 'ul', 'table', 'div', 'dl', 'dd', 'dt']:
                element_text = current_element.get_text()
                content_texts.append(element_text)
                all_element_text += " " + element_text
                
                # より包括的な情報抽出
                if current_element.name in ['p', 'div']:
                    # pタグとdivタグからの抽出
                    lines = [line.strip() for line in element_text.split('\n') if line.strip()]
                    
                    for line in lines:
                        # 住所抽出
                        if not facility['address']:
                            address = self.extract_address_from_text(line)
                            if address:
                                facility['address'] = address
                        
                        # 電話番号を複数パターンで抽出
                        phone_patterns = [
                            r'電話[：:]\s*(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                            r'TEL[：:]\s*(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                            r'(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                            r'(\d{4}[-\s]\d{3}[-\s]\d{3})'  # 0120等のフリーダイヤル
                        ]
                        
                        for phone_pattern in phone_patterns:
                            phone_match = re.search(phone_pattern, line)
                            if phone_match and not facility['phone']:
                                phone_number = phone_match.group(1).replace(' ', '-')
                                facility['phone'] = phone_number
                                break
                
                elif current_element.name == 'ul':
                    # リスト形式の情報を抽出（改善版）
                    list_items = current_element.find_all('li')
                    for li in list_items:
                        li_text = li.get_text(strip=True)
                        
                        # 住所抽出
                        if not facility['address']:
                            address = self.extract_address_from_text(li_text)
                            if address:
                                facility['address'] = address
                        
                        # 電話番号
                        phone_patterns = [
                            r'電話[：:]\s*(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                            r'TEL[：:]\s*(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                            r'(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                            r'(\d{4}[-\s]\d{3}[-\s]\d{3})'
                        ]
                        
                        for phone_pattern in phone_patterns:
                            phone_match = re.search(phone_pattern, li_text)
                            if phone_match and not facility['phone']:
                                phone_number = phone_match.group(1).replace(' ', '-')
                                facility['phone'] = phone_number
                                break
                        
                        # 収容台数
                        capacity_match = re.search(r'(\d+)\s*台', li_text)
                        if capacity_match:
                            facility['capacity'] = capacity_match.group()
                        
                        # 原付対応
                        if '原付' in li_text:
                            if '利用できません' in li_text or '利用不可' in li_text:
                                facility['motorbike_support'] = '利用不可'
                            elif '利用できます' in li_text or '利用可能' in li_text:
                                facility['motorbike_support'] = '利用可能'
                        
                        # 利用時間（改善版）
                        if not facility['hours']:
                            extracted_hours = self.extract_operating_hours(li_text)
                            if extracted_hours:
                                facility['hours'] = extracted_hours
                
                elif current_element.name == 'table':
                    # テーブル形式の詳細情報を抽出（改善版 + 料金テーブル対応）
                    rows = current_element.find_all('tr')
                    
                    # まず料金テーブルかどうかを判定
                    is_fee_table = False
                    header_row = None
                    for row in rows:
                        cells = row.find_all(['th', 'td'])
                        row_text = ' '.join([cell.get_text(strip=True) for cell in cells])
                        if '時間利用' in row_text or 'コイン式' in row_text:
                            is_fee_table = True
                            header_row = row
                            break
                    
                    if is_fee_table and header_row:
                        # 料金テーブルの処理
                        header_cells = header_row.find_all(['th', 'td'])
                        coin_column_index = -1
                        hours_column_index = -1
                        
                        for i, cell in enumerate(header_cells):
                            cell_text = cell.get_text(strip=True)
                            if '時間利用' in cell_text or 'コイン式' in cell_text:
                                coin_column_index = i
                            elif '利用時間' in cell_text:
                                hours_column_index = i
                        
                        # データ行から情報を抽出
                        for row in rows:
                            cells = row.find_all(['td', 'th'])
                            if len(cells) > max(coin_column_index, hours_column_index):
                                # 時間利用（コイン式）の料金を抽出
                                if coin_column_index >= 0 and coin_column_index < len(cells):
                                    coin_fee = cells[coin_column_index].get_text(strip=True)
                                    if coin_fee and coin_fee != 'なし' and '円' in coin_fee and not facility['fee']:
                                        facility['fee'] = self.clean_text_content(coin_fee)
                                
                                # 利用時間を抽出
                                if hours_column_index >= 0 and hours_column_index < len(cells):
                                    hours_text = cells[hours_column_index].get_text(strip=True)
                                    # ヘッダー文字列を除外
                                    if hours_text and hours_text != '利用時間' and not facility['hours']:
                                        extracted_hours = self.extract_operating_hours(hours_text)
                                        if extracted_hours:
                                            facility['hours'] = extracted_hours
                    
                    # 通常のテーブル処理
                    for row in rows:
                        cells = row.find_all(['td', 'th'])
                        if len(cells) >= 2:
                            key_cell = cells[0].get_text(strip=True)
                            value_cell = cells[1].get_text(strip=True)
                            
                            # 住所
                            if '住所' in key_cell and not facility['address']:
                                address = self.extract_address_from_text(value_cell)
                                if address:
                                    facility['address'] = address
                            
                            # 電話番号
                            elif '電話' in key_cell or 'TEL' in key_cell:
                                phone_patterns = [
                                    r'(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                                    r'(\d{4}[-\s]\d{3}[-\s]\d{3})'
                                ]
                                for phone_pattern in phone_patterns:
                                    phone_match = re.search(phone_pattern, value_cell)
                                    if phone_match and not facility['phone']:
                                        facility['phone'] = phone_match.group(1).replace(' ', '-')
                                        break
                            
                            # 利用時間
                            elif '利用時間' in key_cell or '営業時間' in key_cell:
                                if not facility['hours']:
                                    extracted_hours = self.extract_operating_hours(value_cell)
                                    if extracted_hours:
                                        facility['hours'] = extracted_hours
                            
                            # 料金（コイン式のみ）
                            elif '料金' in key_cell or '利用料金' in key_cell:
                                if not facility['fee']:
                                    coin_fee = self.extract_coin_fee_info(value_cell)
                                    if coin_fee:
                                        facility['fee'] = coin_fee
                            
                            # 収容台数
                            elif '台数' in key_cell or '収容' in key_cell:
                                capacity_match = re.search(r'(\d+)\s*台', value_cell)
                                if capacity_match:
                                    facility['capacity'] = capacity_match.group()
                            
                            # 原付対応
                            elif '原付' in key_cell or 'バイク' in key_cell:
                                motorbike_support = self.determine_motorbike_support(value_cell, '')
                                if motorbike_support:
                                    facility['motorbike_support'] = motorbike_support
                
                # 次の要素へ
                current_element = current_element.find_next_sibling()
                
                # h3タグに遭遇したら停止
                if current_element and current_element.name == 'h3':
                    break
            
            # 全体のテキストから包括的な情報を抽出
            if all_element_text:
                # 住所がまだ見つからない場合
                if not facility['address']:
                    address = self.extract_address_from_text(all_element_text)
                    if address:
                        facility['address'] = address
                
                # コイン式料金情報を抽出
                if not facility['fee']:
                    coin_fee = self.extract_coin_fee_info(all_element_text)
                    if coin_fee:
                        facility['fee'] = coin_fee
                    else:
                        # 料金情報が見つからない場合は「定期利用のみ」とする
                        facility['fee'] = '定期利用のみ'
                
                # 電話番号がまだ見つからない場合
                if not facility['phone']:
                    phone_patterns = [
                        r'電話[：:]\s*(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                        r'TEL[：:]\s*(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                        r'(\d{2,4}[-\s]\d{2,4}[-\s]\d{4})',
                        r'(\d{4}[-\s]\d{3}[-\s]\d{3})'
                    ]
                    
                    for phone_pattern in phone_patterns:
                        phone_match = re.search(phone_pattern, all_element_text)
                        if phone_match:
                            facility['phone'] = phone_match.group(1).replace(' ', '-')
                            break
                
                # 利用時間がまだ見つからない場合
                if not facility['hours']:
                    extracted_hours = self.extract_operating_hours(all_element_text)
                    if extracted_hours:
                        facility['hours'] = extracted_hours
                
                # 収容台数
                if not facility['capacity']:
                    capacity_match = re.search(r'(\d+)\s*台', all_element_text)
                    if capacity_match:
                        facility['capacity'] = capacity_match.group()
                
                # 原付対応（最終判定）
                if not facility['motorbike_support']:
                    motorbike_support = self.determine_motorbike_support(all_element_text, facility['capacity'])
                    if motorbike_support:
                        facility['motorbike_support'] = motorbike_support
            
            # 最低限の情報が揃っている場合のみ追加
            if facility['name'] and (facility['address'] or facility['phone'] or facility['hours'] or facility['fee']):
                facilities.append(facility)
        
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
            
            # 住所と利用時間が見つからない駐輪場について、ページ全体から情報を検索
            page_text = soup.get_text()
            for facility in facilities:
                if not facility['address'] or not facility['hours']:
                    # 駐輪場名の前後から情報を抽出
                    name_pattern = re.escape(facility['name'])
                    # 駐輪場名の周辺テキストを広めに取得
                    match = re.search(name_pattern + r'[^\n]*?(?:\n[^\n]*?){0,5}', page_text)
                    if match:
                        context_text = match.group()
                        
                        # 住所抽出
                        if not facility['address']:
                            potential_address = self.extract_address_from_text(context_text)
                            if potential_address:
                                facility['address'] = potential_address
                                self.log(f"ページ全体から住所発見: {facility['name']} - {potential_address}")
                        
                        # 利用時間抽出
                        if not facility['hours']:
                            # 24時間の検出
                            if '24時間' in context_text:
                                facility['hours'] = '24時間'
                                self.log(f"ページ全体から利用時間発見: {facility['name']} - 24時間")
                            else:
                                # 時間パターンの検索（強化版）
                                time_patterns = [
                                    r'午前\d+時から\s*深夜\d+時\d+分',
                                    r'午前\d+時.*?深夜\d+時\d+分',
                                    r'午前\d+時.*?午後\d+時.*?\d+分',
                                    r'午前\d+時.*?午後\d+時',
                                    r'\d+時.*?深夜\d+時',
                                    r'\d+時.*?\d+時\d+分',
                                    r'午前\d+時\s*深夜\d+時\d+分',
                                    r'午前\d+時\s+から\s+深夜\d+時\d+分'
                                ]
                                
                                for pattern in time_patterns:
                                    time_match = re.search(pattern, context_text)
                                    if time_match:
                                        facility['hours'] = time_match.group()
                                        self.log(f"ページ全体から利用時間発見: {facility['name']} - {facility['hours']}")
                                        break
            
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