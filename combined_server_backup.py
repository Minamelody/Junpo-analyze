#!/usr/bin/env python3
"""
Combined server: Flutter Web + Proxy API
"""

from flask import Flask, send_from_directory, request, jsonify
from flask_cors import CORS
import requests
from bs4 import BeautifulSoup
import re
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*", "methods": ["GET", "POST", "OPTIONS"]}}, supports_credentials=True)

# Flutter web build directory
WEB_DIR = '/home/user/flutter_app/build/web'
BASE_URL = 'https://jyanken-poker.onrender.com'
sessions = {}

# Serve Flutter web app
@app.route('/')
def serve_index():
    return send_from_directory(WEB_DIR, 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    # Check if it's an API request
    if path.startswith('proxy/'):
        # This will be handled by API routes
        return jsonify({'error': 'Not found'}), 404
    
    # Serve static files
    if os.path.exists(os.path.join(WEB_DIR, path)):
        return send_from_directory(WEB_DIR, path)
    else:
        return send_from_directory(WEB_DIR, 'index.html')

# API Routes
@app.route('/proxy/api/login', methods=['POST', 'OPTIONS'])
def login():
    if request.method == 'OPTIONS':
        return '', 204
    
    data = request.json
    email = data.get('email')
    password = data.get('password')
    
    if not email or not password:
        return jsonify({'success': False, 'error': 'Email and password required'}), 400
    
    session = requests.Session()
    
    try:
        login_page = session.get(f'{BASE_URL}/users/sign_in')
        soup = BeautifulSoup(login_page.text, 'html.parser')
        token_input = soup.find('input', {'name': 'authenticity_token'})
        
        if not token_input:
            return jsonify({'success': False, 'error': 'CSRF token not found'}), 500
        
        csrf_token = token_input.get('value')
        
        login_response = session.post(
            f'{BASE_URL}/users/sign_in',
            data={
                'user[email]': email,
                'user[password]': password,
                'authenticity_token': csrf_token,
            },
            allow_redirects=True
        )
        
        if login_response.status_code == 200:
            if 'store_visit_applications' in login_response.url or 'players' in login_response.url:
                session_id = f"{email}_{hash(password)}"
                sessions[session_id] = session
                
                return jsonify({
                    'success': True,
                    'session_id': session_id,
                    'message': 'Login successful'
                })
        
        return jsonify({'success': False, 'error': 'Invalid credentials'}), 401
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/proxy/api/chip_histories', methods=['GET', 'OPTIONS'])
def get_chip_histories():
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    if not session_id or session_id not in sessions:
        return jsonify({'success': False, 'error': 'Not authenticated'}), 401
    
    session = sessions[session_id]
    store_id = request.args.get('store_id', '6')
    month = request.args.get('month')  # 変更: year_month -> month
    
    try:
        if month:
            url = f'{BASE_URL}/players/chip_histories?month={month}&store_id={store_id}'
        else:
            url = f'{BASE_URL}/players/chip_histories?store_id={store_id}'
        
        response = session.get(url)
        
        if response.status_code != 200:
            return jsonify({'success': False, 'error': 'Failed to fetch data'}), 500
        
        chip_data = parse_chip_history(response.text)
        
        return jsonify({
            'success': True,
            'data': chip_data
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/proxy/api/stores', methods=['GET', 'OPTIONS'])
def get_stores():
    """Get available stores list"""
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    if not session_id or session_id not in sessions:
        return jsonify({'success': False, 'error': 'Not authenticated'}), 401
    
    session = sessions[session_id]
    
    try:
        response = session.get(f'{BASE_URL}/players/chip_histories')
        
        if response.status_code != 200:
            return jsonify({'success': False, 'error': 'Failed to fetch stores'}), 500
        
        soup = BeautifulSoup(response.text, 'html.parser')
        stores = []
        
        store_select = soup.find('select', {'name': 'store_id'})
        if store_select:
            for option in store_select.find_all('option'):
                stores.append({
                    'id': option.get('value'),
                    'name': option.get_text(strip=True)
                })
        
        return jsonify({
            'success': True,
            'stores': stores
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/proxy/api/chip_histories_batch', methods=['POST', 'OPTIONS'])
def get_chip_histories_batch():
    """Batch fetch chip histories for multiple months with parallel processing"""
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    if not session_id or session_id not in sessions:
        return jsonify({'success': False, 'error': 'Not authenticated'}), 401
    
    session = sessions[session_id]
    data = request.json
    store_id = data.get('store_id', '6')
    months = data.get('months', [])  # List of months like ["2025-12", "2025-11"]
    
    if not months:
        return jsonify({'success': False, 'error': 'No months provided'}), 400
    
    try:
        all_chip_data = []
        
        # 並列処理で複数の月のデータを同時取得（最大10並列）
        def fetch_month_data(month):
            url = f'{BASE_URL}/players/chip_histories?month={month}&store_id={store_id}'
            try:
                response = session.get(url, timeout=10)
                if response.status_code == 200:
                    return parse_chip_history(response.text)
            except Exception:
                pass
            return []
        
        # ThreadPoolExecutorで並列実行
        with ThreadPoolExecutor(max_workers=10) as executor:
            future_to_month = {executor.submit(fetch_month_data, month): month for month in months}
            
            for future in as_completed(future_to_month):
                try:
                    chip_data = future.result()
                    all_chip_data.extend(chip_data)
                except Exception:
                    continue
        
        # 日付ベースで重複を除去
        seen_dates = set()
        unique_data = []
        for item in all_chip_data:
            if item['date'] not in seen_dates:
                seen_dates.add(item['date'])
                unique_data.append(item)
        
        # 日付順にソート（降順）
        unique_data.sort(key=lambda x: x['date'], reverse=True)
        
        return jsonify({
            'success': True,
            'data': unique_data
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/proxy/api/logout', methods=['POST', 'OPTIONS'])
def logout():
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    if session_id and session_id in sessions:
        del sessions[session_id]
    
    return jsonify({'success': True, 'message': 'Logged out'})

def parse_chip_history(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    sessions_data = []
    
    date_divs = soup.find_all('div', class_='histories-date')
    
    for date_div in date_divs:
        # 店舗名を取得（各日付の直後にある）
        store_name = None
        store_div = date_div.find_next_sibling('div', class_='histories-store-name')
        if store_div:
            store_name = store_div.get_text(strip=True)
        try:
            date_text = date_div.get_text(strip=True)
            date_match = re.search(r'(\d{4})年(\d{1,2})月(\d{1,2})日', date_text)
            if not date_match:
                continue
            
            year = date_match.group(1)
            month = date_match.group(2).zfill(2)
            day = date_match.group(3).zfill(2)
            date = f"{year}-{month}-{day}"
            
            balance_match = re.search(r'([\d,]+)ポイント', date_text)
            balance = int(balance_match.group(1).replace(',', '')) if balance_match else 0
            
            next_element = date_div.find_next_sibling()
            while next_element and 'histories-table' not in next_element.get('class', []):
                next_element = next_element.find_next_sibling()
            
            if not next_element:
                continue
            
            tbody = next_element.find('tbody')
            if not tbody:
                continue
            
            rows = tbody.find_all('tr')
            if len(rows) < 2:
                continue
            
            data_row = rows[1]
            cells = data_row.find_all('td')
            
            if len(cells) < 3:
                continue
            
            ring_text = cells[0].get_text(strip=True)
            tournament_text = cells[1].get_text(strip=True)
            purchase_text = cells[2].get_text(strip=True)
            
            ring = int(re.sub(r'[^\d-]', '', ring_text)) if ring_text else 0
            tournament = int(re.sub(r'[^\d-]', '', tournament_text)) if tournament_text else 0
            purchase = int(re.sub(r'[^\d-]', '', purchase_text)) if purchase_text else 0
            
            tfoot = next_element.find('tfoot')
            total_change = 0
            if tfoot:
                tfoot_cells = tfoot.find_all('td')
                if tfoot_cells:
                    change_text = tfoot_cells[-1].get_text(strip=True)
                    total_change = int(re.sub(r'[^\d-]', '', change_text)) if change_text else 0
            
            sessions_data.append({
                'date': date,
                'ring': ring,
                'tournament': tournament,
                'purchase': purchase,
                'total_change': total_change,
                'balance': balance,
                'store_name': store_name,
            })
            
        except Exception:
            continue
    
    return sessions_data

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5060, debug=False)
