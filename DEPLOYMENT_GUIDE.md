# 🚀 じゃんぽ分析 - 無料本番環境デプロイガイド

## 📋 構成

- **フロントエンド**: Flutter Web → Vercel（無料）
- **バックエンド**: Flask API → Render（無料）
- **総費用**: $0/月 ✨

---

## 🎯 デプロイ手順

### パート1：GitHubにコードをアップロード

#### 1-1. GitHubアカウント準備
- GitHub.com でアカウント作成（無料）
- 新しいリポジトリを作成：`jyanpo-analyze`

#### 1-2. コードをGitHubにプッシュ

**ダウンロード済みバックアップ:**
- https://www.genspark.ai/api/files/s/j5pQ1vIk

**手順:**
```bash
# バックアップを展開
tar -xzf jyanpo_analyze_complete_v1.1.tar.gz

# Gitリポジトリ初期化
cd flutter_app
git init
git add .
git commit -m "Initial commit: じゃんぽ分析 v1.1"

# GitHubにプッシュ
git remote add origin https://github.com/あなたのユーザー名/jyanpo-analyze.git
git branch -M main
git push -u origin main
```

---

### パート2：Render（バックエンドAPI）デプロイ

#### 2-1. Renderアカウント作成
- https://render.com でサインアップ（GitHubアカウントで連携可能）

#### 2-2. 新しいWeb Serviceを作成

1. **Dashboard** → **New +** → **Web Service**
2. **Connect GitHub repository**: `jyanpo-analyze`
3. **設定:**
   ```
   Name: jyanpo-api
   Region: Singapore（アジアに近い）
   Branch: main
   Root Directory: (空欄)
   Runtime: Python 3
   Build Command: pip install -r requirements.txt
   Start Command: python combined_server.py
   ```

4. **Environment Variables:**
   ```
   PORT = 5060
   PYTHON_VERSION = 3.12.11
   ```

5. **Instance Type**: Free

6. **Create Web Service** をクリック

#### 2-3. デプロイURL取得
デプロイ完了後、URLが表示されます：
```
例: https://jyanpo-api.onrender.com
```

このURLをメモしてください！⚠️

---

### パート3：Vercel（フロントエンド）デプロイ

#### 3-1. Vercelアカウント作成
- https://vercel.com でサインアップ（GitHubアカウントで連携）

#### 3-2. Flutter Webをビルド（ローカル）

APIエンドポイントを本番用に設定してビルド：

```bash
cd flutter_app

# Render APIのURLを指定してビルド
flutter build web --release \
  --dart-define=API_BASE_URL=https://jyanpo-api.onrender.com/proxy
```

#### 3-3. Vercelにデプロイ

**方法A: Vercel CLI（推奨）**
```bash
# Vercel CLIインストール
npm install -g vercel

# ログイン
vercel login

# デプロイ
cd build/web
vercel --prod
```

**方法B: GitHubから自動デプロイ**
1. Vercel Dashboard → **New Project**
2. **Import Git Repository**: `jyanpo-analyze`
3. **Framework Preset**: Other
4. **Root Directory**: `build/web`
5. **Environment Variables:**
   ```
   API_BASE_URL = https://jyanpo-api.onrender.com/proxy
   ```
6. **Deploy** をクリック

#### 3-4. デプロイURL取得
```
例: https://jyanpo-analyze.vercel.app
```

---

## ✅ デプロイ完了！

### 🌐 あなたの本番環境URL

- **アプリURL**: `https://jyanpo-analyze.vercel.app`
- **API URL**: `https://jyanpo-api.onrender.com`

### 📱 使い方

1. ブラウザで `https://jyanpo-analyze.vercel.app` を開く
2. じゃんけんポーカーのアカウントでログイン
3. 収支を分析！

**このURLは永続的に使えます！** 🎉

---

## 🔧 本番環境の特徴

### Render（Flask API）無料プラン
- ✅ 24/7稼働
- ⚠️ 15分間アクセスなしでスリープ
- ⚠️ スリープから復帰まで数秒かかる
- ✅ 月750時間（十分）

### Vercel（Flutter Web）無料プラン
- ✅ 24/7稼働
- ✅ 高速CDN
- ✅ 自動HTTPS
- ✅ 無制限リクエスト（個人利用なら）

---

## 💡 使用時の注意点

### 初回アクセスが遅い場合
Render無料プランは15分間アクセスがないとスリープします。

**対策:**
- 初回ログイン時は10秒ほど待つ
- 2回目以降は通常速度

### スリープを防ぐ方法（オプション）
UptimeRobot（無料）で5分おきにAPIをpingする設定が可能

---

## 🔄 更新方法

コードを修正した場合：

```bash
# 変更をコミット
git add .
git commit -m "Update: 機能追加"
git push

# Render, Vercelが自動的に再デプロイ！
```

---

## 🆘 トラブルシューティング

### ❌ ログインできない
1. Render APIのURLが正しいか確認
2. RenderのログでAPIが起動しているか確認
3. CORS設定を確認

### ❌ データが取得できない
1. ブラウザのDevToolsでネットワークエラーを確認
2. API URLが正しくビルドされているか確認

### ❌ Renderが遅い
- 初回アクセスはスリープ復帰のため遅い（正常）
- 有料プラン（$7/月）で常時起動可能

---

## 📊 コスト比較

| プラン | 月額 | スリープ | 起動時間 |
|--------|------|----------|----------|
| **無料（現在）** | $0 | あり | 数秒 |
| Render有料 | $7 | なし | 即座 |

個人利用なら無料で十分です！

---

## 🎯 まとめ

1. ✅ **GitHub**: コードをアップロード
2. ✅ **Render**: Flaskサーバーをデプロイ（API）
3. ✅ **Vercel**: Flutter Webをデプロイ（フロント）
4. ✅ **完成**: 永続的な固定URLで使える！

**所要時間**: 約30分
**費用**: 完全無料 $0/月

---

**質問があればチャットでサポートします！** 🚀
