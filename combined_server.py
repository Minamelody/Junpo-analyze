#!/usr/bin/env python3
"""
Combined server: Flutter Web + Proxy API (Security Enhanced)
"""

from flask import Flask, send_from_directory, request, jsonify
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import requests
from bs4 import BeautifulSoup
import re
import os
import secrets
import hashlib
import time
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging

# ロギング設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# 🔒 セキュリティ設定
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', secrets.token_hex(32))
app.config['SESSION_COOKIE_SECURE'] = True  # HTTPS only
app.config['SESSION_COOKIE_HTTPONLY'] = True  # XSS対策
app.config['SESSION_COOKIE_SAMESITE'] = 'Strict'  # CSRF対策

# 🔒 CORS設定（特定のオリジンのみ許可）
# 開発中は緩和、本番環境では厳格化推奨
DEV_MODE = os.environ.get('DEV_MODE', 'true').lower() == 'true'

if DEV_MODE:
    # 開発モード: すべてのVercelドメインとサンドボックスを許可
    CORS(app, 
         resources={r"/*": {
             "origins": "*",  # 開発中は全許可
             "methods": ["GET", "POST", "OPTIONS"],
             "allow_headers": ["Content-Type", "X-Session-ID"],
             "expose_headers": ["Content-Type"],
             "supports_credentials": False,  # *を使う場合はFalse必須
             "max_age": 3600
         }})
    logger.info("🔓 CORS: Development mode - all origins allowed")
else:
    # 本番モード: 特定のオリジンのみ
    ALLOWED_ORIGINS = [
        'https://5060-imv460mslw8g37var1eds-3844e1b6.sandbox.novita.ai',
        'https://junpo-analyze.vercel.app',
        'http://localhost:5060',
    ]
    CORS(app, 
         resources={r"/*": {
             "origins": ALLOWED_ORIGINS,
             "methods": ["GET", "POST", "OPTIONS"],
             "allow_headers": ["Content-Type", "X-Session-ID"],
             "expose_headers": ["Content-Type"],
             "supports_credentials": True,
             "max_age": 3600
         }})
    logger.info(f"🔒 CORS: Production mode - allowed origins: {ALLOWED_ORIGINS}")

# 🔒 レート制限設定
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"],
    storage_uri="memory://"
)

# Flutter web build directory
WEB_DIR = '/home/user/flutter_app/build/web'
BASE_URL = 'https://jyanken-poker.onrender.com'

# 🔒 セキュアなセッション管理
class SecureSessionManager:
    def __init__(self):
        self.sessions = {}
        self.session_timeout = timedelta(hours=2)  # 2時間でタイムアウト
    
    def create_session(self, email: str) -> str:
        """セキュアなセッションIDを生成"""
        session_id = secrets.token_urlsafe(32)
        self.sessions[session_id] = {
            'session': requests.Session(),
            'email_hash': hashlib.sha256(email.encode()).hexdigest(),
            'created_at': datetime.now(),
            'last_accessed': datetime.now()
        }
        logger.info(f"Session created: {session_id[:8]}...")
        return session_id
    
    def get_session(self, session_id: str):
        """セッションを取得（タイムアウトチェック付き）"""
        if session_id not in self.sessions:
            return None
        
        session_data = self.sessions[session_id]
        
        # タイムアウトチェック
        if datetime.now() - session_data['last_accessed'] > self.session_timeout:
            logger.warning(f"Session timeout: {session_id[:8]}...")
            self.delete_session(session_id)
            return None
        
        # アクセス時刻を更新
        session_data['last_accessed'] = datetime.now()
        return session_data['session']
    
    def delete_session(self, session_id: str):
        """セッションを削除"""
        if session_id in self.sessions:
            del self.sessions[session_id]
            logger.info(f"Session deleted: {session_id[:8]}...")
    
    def cleanup_expired_sessions(self):
        """期限切れセッションをクリーンアップ"""
        now = datetime.now()
        expired = [
            sid for sid, data in self.sessions.items()
            if now - data['last_accessed'] > self.session_timeout
        ]
        for sid in expired:
            self.delete_session(sid)
        if expired:
            logger.info(f"Cleaned up {len(expired)} expired sessions")

session_manager = SecureSessionManager()

# 🔒 入力検証関数
def validate_email(email: str) -> bool:
    """メールアドレスの形式検証"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email)) and len(email) <= 254

def validate_month(month: str) -> bool:
    """月形式の検証 (YYYY-MM)"""
    pattern = r'^\d{4}-(0[1-9]|1[0-2])$'
    return bool(re.match(pattern, month))

def validate_store_id(store_id: str) -> bool:
    """店舗IDの検証（数値のみ）"""
    return store_id.isdigit() and 1 <= int(store_id) <= 100

def sanitize_error_message(error: Exception) -> str:
    """エラーメッセージをサニタイズ（内部情報を隠す）"""
    error_str = str(error)
    # 内部パスやスタックトレースを隠す
    if '/' in error_str or '\\' in error_str:
        return "Internal server error"
    return "An error occurred"

# Serve Flutter web app
@app.route('/')
def serve_index():
    return send_from_directory(WEB_DIR, 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    # Check if it's an API request
    if path.startswith('proxy/'):
        return jsonify({'error': 'Not found'}), 404
    
    # 🔒 パストラバーサル対策
    safe_path = os.path.normpath(path).lstrip('/')
    if '..' in safe_path or safe_path.startswith('/'):
        return jsonify({'error': 'Invalid path'}), 400
    
    # Serve static files
    full_path = os.path.join(WEB_DIR, safe_path)
    if os.path.exists(full_path) and os.path.commonpath([WEB_DIR, full_path]) == WEB_DIR:
        return send_from_directory(WEB_DIR, safe_path)
    else:
        return send_from_directory(WEB_DIR, 'index.html')

# 🔒 API Routes with Security
@app.route('/proxy/api/login', methods=['POST', 'OPTIONS'])
@limiter.limit("10 per minute")  # ログイン試行回数制限
def login():
    if request.method == 'OPTIONS':
        return '', 204
    
    try:
        data = request.json
        email = data.get('email', '').strip()
        password = data.get('password', '')
        
        # 🔒 入力検証
        if not email or not password:
            return jsonify({'success': False, 'error': 'Email and password required'}), 400
        
        if not validate_email(email):
            return jsonify({'success': False, 'error': 'Invalid email format'}), 400
        
        if len(password) < 6 or len(password) > 128:
            return jsonify({'success': False, 'error': 'Invalid password length'}), 400
        
        session = requests.Session()
        
        try:
            login_page = session.get(f'{BASE_URL}/users/sign_in', timeout=10)
            soup = BeautifulSoup(login_page.text, 'html.parser')
            token_input = soup.find('input', {'name': 'authenticity_token'})
            
            if not token_input:
                logger.error("CSRF token not found")
                return jsonify({'success': False, 'error': 'Authentication failed'}), 500
            
            csrf_token = token_input.get('value')
            
            login_response = session.post(
                f'{BASE_URL}/users/sign_in',
                data={
                    'user[email]': email,
                    'user[password]': password,
                    'authenticity_token': csrf_token,
                },
                allow_redirects=True,
                timeout=15
            )
            
            if login_response.status_code == 200:
                if 'store_visit_applications' in login_response.url or 'players' in login_response.url:
                    # 🔒 セキュアなセッション作成
                    session_id = session_manager.create_session(email)
                    session_manager.sessions[session_id]['session'] = session
                    
                    logger.info(f"Login successful for email hash: {hashlib.sha256(email.encode()).hexdigest()[:8]}...")
                    
                    return jsonify({
                        'success': True,
                        'session_id': session_id,
                        'message': 'Login successful'
                    })
            
            logger.warning(f"Login failed for email: {email}")
            return jsonify({'success': False, 'error': 'Invalid credentials'}), 401
            
        except requests.Timeout:
            logger.error("Login request timeout")
            return jsonify({'success': False, 'error': 'Request timeout'}), 504
        except Exception as e:
            logger.error(f"Login error: {sanitize_error_message(e)}")
            return jsonify({'success': False, 'error': 'Authentication failed'}), 500
    
    except Exception as e:
        logger.error(f"Unexpected error in login: {sanitize_error_message(e)}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@app.route('/proxy/api/chip_histories', methods=['GET', 'OPTIONS'])
@limiter.limit("100 per minute")
def get_chip_histories():
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    # 🔒 セッション検証
    if not session_id:
        return jsonify({'success': False, 'error': 'Not authenticated'}), 401
    
    session = session_manager.get_session(session_id)
    if not session:
        return jsonify({'success': False, 'error': 'Session expired'}), 401
    
    store_id = request.args.get('store_id', '6')
    month = request.args.get('month')
    
    # 🔒 入力検証
    if not validate_store_id(store_id):
        return jsonify({'success': False, 'error': 'Invalid store ID'}), 400
    
    if month and not validate_month(month):
        return jsonify({'success': False, 'error': 'Invalid month format'}), 400
    
    try:
        if month:
            url = f'{BASE_URL}/players/chip_histories?month={month}&store_id={store_id}'
        else:
            url = f'{BASE_URL}/players/chip_histories?store_id={store_id}'
        
        response = session.get(url, timeout=10)
        
        if response.status_code != 200:
            return jsonify({'success': False, 'error': 'Failed to fetch data'}), 500
        
        chip_data = parse_chip_history(response.text)
        
        return jsonify({
            'success': True,
            'data': chip_data
        })
        
    except requests.Timeout:
        return jsonify({'success': False, 'error': 'Request timeout'}), 504
    except Exception as e:
        logger.error(f"Error fetching chip histories: {sanitize_error_message(e)}")
        return jsonify({'success': False, 'error': 'Failed to fetch data'}), 500

@app.route('/proxy/api/stores', methods=['GET', 'OPTIONS'])
@limiter.limit("50 per minute")
def get_stores():
    """Get available stores list"""
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    # 🔒 セッション検証
    if not session_id:
        return jsonify({'success': False, 'error': 'Not authenticated'}), 401
    
    session = session_manager.get_session(session_id)
    if not session:
        return jsonify({'success': False, 'error': 'Session expired'}), 401
    
    try:
        response = session.get(f'{BASE_URL}/players/chip_histories', timeout=10)
        
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
        
    except requests.Timeout:
        return jsonify({'success': False, 'error': 'Request timeout'}), 504
    except Exception as e:
        logger.error(f"Error fetching stores: {sanitize_error_message(e)}")
        return jsonify({'success': False, 'error': 'Failed to fetch stores'}), 500

@app.route('/proxy/api/chip_histories_batch', methods=['POST', 'OPTIONS'])
@limiter.limit("20 per minute")
def get_chip_histories_batch():
    """Batch fetch chip histories for multiple months with parallel processing"""
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    # 🔒 セッション検証
    if not session_id:
        return jsonify({'success': False, 'error': 'Not authenticated'}), 401
    
    session = session_manager.get_session(session_id)
    if not session:
        return jsonify({'success': False, 'error': 'Session expired'}), 401
    
    data = request.json
    store_id = data.get('store_id', '6')
    months = data.get('months', [])
    
    # 🔒 入力検証
    if not validate_store_id(store_id):
        return jsonify({'success': False, 'error': 'Invalid store ID'}), 400
    
    if not months or not isinstance(months, list):
        return jsonify({'success': False, 'error': 'No months provided'}), 400
    
    # 🔒 月数制限（DoS対策）
    if len(months) > 24:
        return jsonify({'success': False, 'error': 'Too many months requested'}), 400
    
    # 🔒 各月の形式検証
    for month in months:
        if not validate_month(month):
            return jsonify({'success': False, 'error': f'Invalid month format: {month}'}), 400
    
    try:
        all_chip_data = []
        
        def fetch_month_data(month):
            url = f'{BASE_URL}/players/chip_histories?month={month}&store_id={store_id}'
            try:
                response = session.get(url, timeout=10)
                if response.status_code == 200:
                    return parse_chip_history(response.text)
            except Exception as e:
                logger.warning(f"Error fetching month {month}: {sanitize_error_message(e)}")
            return []
        
        # 🔒 並列処理（最大10並列）
        with ThreadPoolExecutor(max_workers=10) as executor:
            future_to_month = {executor.submit(fetch_month_data, month): month for month in months}
            
            for future in as_completed(future_to_month):
                month_data = future.result()
                all_chip_data.extend(month_data)
        
        # 🔒 重複除去（日付とstore_idで）
        unique_data = {}
        for item in all_chip_data:
            key = f"{item.get('date')}_{item.get('store_id')}"
            if key not in unique_data:
                unique_data[key] = item
        
        sorted_data = sorted(unique_data.values(), key=lambda x: x.get('date', ''), reverse=True)
        
        return jsonify({
            'success': True,
            'data': sorted_data
        })
        
    except Exception as e:
        logger.error(f"Error in batch fetch: {sanitize_error_message(e)}")
        return jsonify({'success': False, 'error': 'Failed to fetch data'}), 500

# 🔒 ログアウトエンドポイント
@app.route('/proxy/api/logout', methods=['POST', 'OPTIONS'])
def logout():
    if request.method == 'OPTIONS':
        return '', 204
    
    session_id = request.headers.get('X-Session-ID')
    
    if session_id:
        session_manager.delete_session(session_id)
        logger.info(f"Logout successful: {session_id[:8]}...")
    
    return jsonify({'success': True, 'message': 'Logged out'})

# Parse chip history HTML
def parse_chip_history(html_content):
    """Parse chip history from HTML"""
    soup = BeautifulSoup(html_content, 'html.parser')
    chip_data = []
    
    rows = soup.select('table tbody tr')
    
    for row in rows:
        cols = row.find_all('td')
        if len(cols) >= 7:
            try:
                date_text = cols[0].get_text(strip=True)
                ring_text = cols[1].get_text(strip=True)
                tournament_text = cols[2].get_text(strip=True)
                purchase_text = cols[3].get_text(strip=True)
                total_change_text = cols[4].get_text(strip=True)
                balance_text = cols[5].get_text(strip=True)
                store_text = cols[6].get_text(strip=True)
                
                def parse_number(text):
                    cleaned = re.sub(r'[^\d-]', '', text)
                    return int(cleaned) if cleaned and cleaned != '-' else 0
                
                chip_data.append({
                    'date': date_text,
                    'ring_chips': parse_number(ring_text),
                    'tournament_chips': parse_number(tournament_text),
                    'purchase': parse_number(purchase_text),
                    'total_change': parse_number(total_change_text),
                    'current_balance': parse_number(balance_text),
                    'store_name': store_text
                })
                
            except Exception as e:
                logger.warning(f"Error parsing row: {sanitize_error_message(e)}")
                continue
    
    return chip_data

# 🔒 定期的なセッションクリーンアップ（バックグラウンドタスク）
def cleanup_sessions_periodically():
    """定期的に期限切れセッションをクリーンアップ"""
    import threading
    def cleanup_loop():
        while True:
            time.sleep(3600)  # 1時間ごと
            session_manager.cleanup_expired_sessions()
    
    thread = threading.Thread(target=cleanup_loop, daemon=True)
    thread.start()

# アプリ起動時にクリーンアップスレッドを開始
cleanup_sessions_periodically()

if __name__ == '__main__':
    logger.info("🔒 Starting secure server...")
    logger.info(f"Session timeout: {session_manager.session_timeout}")
    app.run(host='0.0.0.0', port=5060, debug=False)
