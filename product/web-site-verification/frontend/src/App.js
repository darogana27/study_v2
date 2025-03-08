// ファイル: App.js
import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, Navigate } from 'react-router-dom';
import { Amplify } from 'aws-amplify';
import { 
  signIn, 
  signUp, 
  signOut, 
  getCurrentUser, 
  fetchUserAttributes, 
  fetchAuthSession 
} from 'aws-amplify/auth';
import './App.css';

// AWS Amplify設定
const awsConfig = {
  Auth: {
    region: 'REGION', // 例: 'us-east-1'
    userPoolId: 'USER_POOL_ID', // 例: 'us-east-1_xxxxxxxx'
    userPoolWebClientId: 'CLIENT_ID', // 例: 'xxxxxxxxxxxxxxxxxxxxxxxxxx'
  }
};

Amplify.configure(awsConfig);

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isAuthenticating, setIsAuthenticating] = useState(true);
  const [user, setUser] = useState(null);

  useEffect(() => {
    checkAuthState();
  }, []);

  async function checkAuthState() {
    try {
      const session = await fetchAuthSession()
      setIsAuthenticated(true);
      const currentUser = await getCurrentUser();
      setUser(currentUser);
    } catch (error) {
      setIsAuthenticated(false);
      setUser(null);
    }
    setIsAuthenticating(false);
  }

  async function handleLogout() {
    try {
      await signOut();
      setIsAuthenticated(false);
      setUser(null);
    } catch (error) {
      console.error('Error signing out:', error);
    }
  }

  if (isAuthenticating) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <Router basename="/">
      <div className="app">
        <Header isAuthenticated={isAuthenticated} onLogout={handleLogout} user={user} />
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/features" element={<FeaturesPage />} />
          <Route path="/gameplay" element={<GameplayPage />} />
          <Route path="/login" element={!isAuthenticated ? <AuthPage setIsAuthenticated={setIsAuthenticated} setUser={setUser} /> : <Navigate to="/profile" />} />
          <Route path="/profile" element={isAuthenticated ? <ProfilePage user={user} /> : <Navigate to="/login" />} />
        </Routes>
        <Footer />
      </div>
    </Router>
  );
}

// Header Component
function Header({ isAuthenticated, onLogout, user }) {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <header>
      <nav className="navbar">
        <Link to="/" className="logo">EPIC ADVENTURE</Link>
        <div className={`nav-links ${isMenuOpen ? 'active' : ''}`}>
          <Link to="/features">特徴</Link>
          <Link to="/gameplay">ゲームプレイ</Link>
          <Link to="/#countdown">発売日</Link>
          <Link to="/#footer">お問い合わせ</Link>
          {isAuthenticated ? (
            <>
              <Link to="/profile">マイページ</Link>
              <button className="logout-btn" onClick={onLogout}>ログアウト</button>
            </>
          ) : (
            <Link to="/login">ログイン</Link>
          )}
        </div>
        <div className="menu-toggle" onClick={() => setIsMenuOpen(!isMenuOpen)}>
          <span></span>
          <span></span>
          <span></span>
        </div>
      </nav>
    </header>
  );
}

// HomePage Component
function HomePage() {
  const [days, setDays] = useState(0);
  const [hours, setHours] = useState(0);
  const [minutes, setMinutes] = useState(0);
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    const countDownDate = new Date("May 10, 2025 00:00:00").getTime();

    const interval = setInterval(() => {
      const now = new Date().getTime();
      const distance = countDownDate - now;

      setDays(Math.floor(distance / (1000 * 60 * 60 * 24)));
      setHours(Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)));
      setMinutes(Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60)));
      setSeconds(Math.floor((distance % (1000 * 60)) / 1000));
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  return (
    <main>
      <section className="hero">
        <div className="hero-content">
          <h1>EPIC ADVENTURE</h1>
          <p>未知の世界への冒険、迫りくる危機、そして運命の戦い。あなたの選択が世界を変える。</p>
          <Link to="/login" className="cta-button">予約する</Link>
        </div>
      </section>

      <section id="countdown" className="countdown">
        <div className="countdown-content">
          <h2>発売まであと</h2>
          <div className="countdown-timer">
            <div className="countdown-item">
              <div className="countdown-number">{days}</div>
              <div className="countdown-label">日</div>
            </div>
            <div className="countdown-item">
              <div className="countdown-number">{hours}</div>
              <div className="countdown-label">時間</div>
            </div>
            <div className="countdown-item">
              <div className="countdown-number">{minutes}</div>
              <div className="countdown-label">分</div>
            </div>
            <div className="countdown-item">
              <div className="countdown-number">{seconds}</div>
              <div className="countdown-label">秒</div>
            </div>
          </div>
          <Link to="/login" className="cta-button">今すぐ予約する</Link>
        </div>
      </section>
    </main>
  );
}

// FeaturesPage Component
function FeaturesPage() {
  return (
    <section className="features">
      <h2 className="section-title">ゲームの特徴</h2>
      <div className="feature-grid">
        <div className="feature-card">
          <div className="feature-icon">🌍</div>
          <h3>広大なオープンワールド</h3>
          <p>自由に探索できる広大な世界。隠された秘密や宝物を探し出そう。</p>
        </div>
        <div className="feature-card">
          <div className="feature-icon">⚔️</div>
          <h3>臨場感あふれる戦闘</h3>
          <p>リアルタイムでスリリングな戦闘を体験。様々な武器や魔法を駆使して戦おう。</p>
        </div>
        <div className="feature-card">
          <div className="feature-icon">🔮</div>
          <h3>魅力的なストーリー</h3>
          <p>プレイヤーの選択で変わる多彩なストーリー展開。あなただけの物語を紡ごう。</p>
        </div>
        <div className="feature-card">
          <div className="feature-icon">👥</div>
          <h3>多彩なキャラクター</h3>
          <p>個性豊かなキャラクターたち。彼らとの交流があなたの冒険を彩る。</p>
        </div>
        <div className="feature-card">
          <div className="feature-icon">🏰</div>
          <h3>多様なダンジョン</h3>
          <p>それぞれ特徴のある多数のダンジョン。強力なボスが待ち受ける。</p>
        </div>
        <div className="feature-card">
          <div className="feature-icon">🎮</div>
          <h3>オンラインマルチプレイ</h3>
          <p>友達と一緒に冒険しよう。協力プレイで強敵に立ち向かえ。</p>
        </div>
      </div>
    </section>
  );
}

// GameplayPage Component
function GameplayPage() {
  return (
    <section className="gameplay">
      <h2 className="section-title">ゲームプレイ</h2>
      <div className="gameplay-content">
        <div className="gameplay-item">
          <div className="gameplay-image">
            <img src="/api/placeholder/600/400" alt="ゲームプレイ画像1" />
          </div>
          <div className="gameplay-text">
            <h3>壮大な冒険</h3>
            <p>広大な世界を自由に探索し、数々の謎を解き明かそう。山、森、湖、砂漠など様々な環境が広がり、それぞれに固有の生態系と秘密が隠されています。</p>
            <p>昼夜や天候のサイクルが実装され、時間帯や環境によって出現するモンスターや入手できるアイテムが変化します。</p>
          </div>
        </div>
        <div className="gameplay-item">
          <div className="gameplay-image">
            <img src="/api/placeholder/600/400" alt="ゲームプレイ画像2" />
          </div>
          <div className="gameplay-text">
            <h3>戦略的な戦闘</h3>
            <p>剣、弓、魔法など様々な戦闘スタイルを選択できます。敵の弱点を見極め、地形を利用した戦略的な戦いを繰り広げましょう。</p>
            <p>レベルアップでスキルポイントを獲得し、自分だけの戦闘スタイルを構築できます。100種類以上の武器と防具、200種類以上の魔法が登場。</p>
          </div>
        </div>
        <div className="gameplay-item">
          <div className="gameplay-image">
            <img src="/api/placeholder/600/400" alt="ゲームプレイ画像3" />
          </div>
          <div className="gameplay-text">
            <h3>キャラクターカスタマイズ</h3>
            <p>細部まで作り込まれたキャラクタークリエイト機能で、自分だけのヒーローを作成しましょう。種族、外見、能力値などを自由にカスタマイズできます。</p>
            <p>ゲーム内で発見する装備品で見た目も能力も変化。他のプレイヤーと差をつけた個性的なキャラクターを作り上げましょう。</p>
          </div>
        </div>
      </div>
    </section>
  );
}

// AuthPage Component (Login & Signup)
function AuthPage({ setIsAuthenticated, setUser }) {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [message, setMessage] = useState({ text: '', type: '' });

  async function handleSubmit(e) {
    e.preventDefault();
    setMessage({ text: '', type: '' });

    if (isLogin) {
      // ログイン処理
      try {
        const user = await signIn({ username: email, password });
        setIsAuthenticated(true);
        setUser(user);
      } catch (error) {
        setMessage({ text: 'ログインエラー: ' + error.message, type: 'error' });
      }
    } else {
      // サインアップ処理
      if (password !== confirmPassword) {
        setMessage({ text: 'パスワードが一致しません', type: 'error' });
        return;
      }

      try {
        await signUp({
          username: email,
          password,
          attributes: {
            email
          }
        });
        setMessage({ text: email + ' でアカウントが作成されました。確認コードが送信されますので、メールをご確認ください。', type: 'success' });
        setTimeout(() => setIsLogin(true), 3000);
      } catch (error) {
        setMessage({ text: 'サインアップエラー: ' + error.message, type: 'error' });
      }
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-container">
        <div className="auth-tabs">
          <button 
            className={`auth-tab ${isLogin ? 'active' : ''}`}
            onClick={() => setIsLogin(true)}
          >
            ログイン
          </button>
          <button 
            className={`auth-tab ${!isLogin ? 'active' : ''}`}
            onClick={() => setIsLogin(false)}
          >
            新規登録
          </button>
        </div>

        <form className="auth-form" onSubmit={handleSubmit}>
          {message.text && (
            <div className={`form-message ${message.type}`}>
              {message.text}
            </div>
          )}

          <div className="form-group">
            <label htmlFor="email">メールアドレス</label>
            <input 
              type="email" 
              id="email" 
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required 
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">パスワード</label>
            <input 
              type="password" 
              id="password" 
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required 
            />
            {!isLogin && (
              <small>8文字以上、大文字・小文字・数字を含む必要があります</small>
            )}
          </div>

          {!isLogin && (
            <div className="form-group">
              <label htmlFor="confirmPassword">パスワード（確認）</label>
              <input 
                type="password" 
                id="confirmPassword" 
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required 
              />
            </div>
          )}

          <button type="submit" className="form-button">
            {isLogin ? 'ログイン' : '登録する'}
          </button>
        </form>
      </div>
    </div>
  );
}

// ProfilePage Component
function ProfilePage({ user }) {
  return (
    <div className="profile-page">
      <div className="profile-container">
        <h2>マイページ</h2>
        <div className="profile-info">
          <p><strong>メールアドレス:</strong> {user.attributes.email}</p>
          <h3>予約状況</h3>
          <p>現在、予約はありません。</p>
          <button className="cta-button">ゲームを予約する</button>
        </div>
      </div>
    </div>
  );
}

// Footer Component
function Footer() {
  return (
    <footer id="footer">
      <div className="footer-content">
        <div className="social-links">
          <a href="#" className="social-link">Twitter</a>
          <a href="#" className="social-link">Instagram</a>
          <a href="#" className="social-link">YouTube</a>
          <a href="#" className="social-link">Discord</a>
        </div>
        <div className="footer-nav">
          <Link to="/">ホーム</Link>
          <Link to="/news">お知らせ</Link>
          <Link to="/faq">FAQ</Link>
          <Link to="/support">サポート</Link>
          <Link to="/privacy">プライバシーポリシー</Link>
        </div>
        <div className="copyright">
          &copy; 2025 EPIC ADVENTURE All Rights Reserved.
        </div>
      </div>
    </footer>
  );
}

export default App;