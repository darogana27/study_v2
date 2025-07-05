// ファイル: App.js
import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, Navigate } from 'react-router-dom';
import { Amplify } from 'aws-amplify';
import { 
  signIn, 
  signUp, 
  signOut, 
  confirmSignUp,
  resendSignUpCode,
  getCurrentUser, 
  fetchUserAttributes, 
  fetchAuthSession 
} from 'aws-amplify/auth';
import './App.css';

// AWS Amplify設定
const awsConfig = {
  Auth: {
    region: 'ap-northeast-1', // 例: 'us-east-1'
    userPoolId: 'ap-northeast-1_NWYQNWHT9', // 例: 'us-east-1_xxxxxxxx'
    userPoolWebClientId: '6rhqaekqs60ucif5bkqail37gj', // 例: 'xxxxxxxxxxxxxxxxxxxxxxxxxx'
    oauth: {
      domain: 'https://ap-northeast-1nwyqnwht9.auth.ap-northeast-1.amazoncognito.com',
      scope: ['phone', 'email','openid'],
      redirectSignIn: 'http://localhost:3000/',
      redirectSignOut: 'http://localhost:3000/',
      responseType: 'code'
    }
  }
};

Amplify.configure(awsConfig);

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isAuthenticating, setIsAuthenticating] = useState(true);
  const [user, setUser] = useState(null);
  const [userAttributes, setUserAttributes] = useState(null);

  useEffect(() => {
    checkAuthState();
  }, []);

  async function checkAuthState() {
    try {
      // セッションと認証状態を確認
      const session = await fetchAuthSession();
      const currentUser = await getCurrentUser();
      
      // ユーザー情報の取得
      const attributes = await fetchUserAttributes();
      
      setIsAuthenticated(true);
      setUser(currentUser);
      setUserAttributes(attributes);
    } catch (error) {
      console.log('認証されていません:', error);
      setIsAuthenticated(false);
      setUser(null);
      setUserAttributes(null);
    } finally {
      setIsAuthenticating(false);
    }
  }

  async function handleLogout() {
    try {
      await signOut();
      setIsAuthenticated(false);
      setUser(null);
      setUserAttributes(null);
    } catch (error) {
      console.error('ログアウトエラー:', error);
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
          <Route 
            path="/login" 
            element={
              !isAuthenticated 
                ? <AuthPage setIsAuthenticated={setIsAuthenticated} setUser={setUser} /> 
                : <Navigate to="/profile" />
            } 
          />
          <Route 
            path="/profile" 
            element={
              isAuthenticated 
                ? <ProfilePage user={user} userAttributes={userAttributes} /> 
                : <Navigate to="/login" />
            } 
          />
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

// AuthPage Component (Login, Signup, Confirmation)
function AuthPage({ setIsAuthenticated, setUser }) {
  const [activeTab, setActiveTab] = useState('login'); // 'login', 'signup', 'confirm'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [confirmationCode, setConfirmationCode] = useState('');
  const [message, setMessage] = useState({ text: '', type: '' });
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setMessage({ text: '', type: '' });
    setLoading(true);

    try {
      if (activeTab === 'login') {
        // ログイン処理
        const { isSignedIn, nextStep } = await signIn({ 
          username: email, 
          password 
        });
        
        if (isSignedIn) {
          const currentUser = await getCurrentUser();
          setIsAuthenticated(true);
          setUser(currentUser);
        } else if (nextStep && nextStep.signInStep === 'CONFIRM_SIGN_UP') {
          // サインアップ確認が必要な場合
          setActiveTab('confirm');
          setMessage({ 
            text: 'アカウントがまだ確認されていません。確認コードを入力してください。', 
            type: 'info' 
          });
        }
      } else if (activeTab === 'signup') {
        // サインアップ処理
        if (password !== confirmPassword) {
          setMessage({ text: 'パスワードが一致しません', type: 'error' });
          setLoading(false);
          return;
        }

        const { isSignUpComplete, userId, nextStep } = await signUp({
          username: email,
          password,
          options: {
            userAttributes: {
              email
            },
            autoSignIn: true
          }
        });

        if (!isSignUpComplete && nextStep.signUpStep === 'CONFIRM_SIGN_UP') {
          setActiveTab('confirm');
          setMessage({ 
            text: email + ' でアカウントが作成されました。確認コードが送信されますので、メールをご確認ください。', 
            type: 'success' 
          });
        }
      } else if (activeTab === 'confirm') {
        // 確認コード検証
        const { isSignUpComplete } = await confirmSignUp({
          username: email,
          confirmationCode
        });

        if (isSignUpComplete) {
          // 自動サインインが有効の場合、ここではすでにサインインされているはず
          try {
            const session = await fetchAuthSession();
            const currentUser = await getCurrentUser();
            setIsAuthenticated(true);
            setUser(currentUser);
            setMessage({ text: 'アカウントが確認され、ログインしました', type: 'success' });
          } catch (error) {
            // 自動サインインが失敗した場合はログイン画面に戻る
            setActiveTab('login');
            setMessage({ text: 'アカウントが確認されました。ログインしてください', type: 'success' });
          }
        }
      }
    } catch (error) {
      console.error('認証エラー:', error);
      
      // エラーメッセージのカスタマイズ
      let errorMsg = 'エラーが発生しました: ' + error.message;
      
      if (error.name === 'UserNotConfirmedException') {
        setActiveTab('confirm');
        errorMsg = 'アカウントが確認されていません。確認コードを入力してください。';
      } else if (error.name === 'NotAuthorizedException') {
        errorMsg = 'メールアドレスまたはパスワードが正しくありません。';
      } else if (error.name === 'UserNotFoundException') {
        errorMsg = 'アカウントが見つかりません。';
      } else if (error.name === 'CodeMismatchException') {
        errorMsg = '確認コードが正しくありません。';
      } else if (error.name === 'LimitExceededException') {
        errorMsg = '試行回数が多すぎます。しばらく時間をおいてからもう一度お試しください。';
      } else if (error.name === 'InvalidPasswordException') {
        errorMsg = 'パスワードポリシーに適合しません。8文字以上で、大文字・小文字・数字を含む必要があります。';
      } else if (error.name === 'UsernameExistsException') {
        errorMsg = 'このメールアドレスは既に登録されています。';
      }
      
      setMessage({ text: errorMsg, type: 'error' });
    } finally {
      setLoading(false);
    }
  }

  // 確認コードの再送信
  async function handleResendCode() {
    try {
      setLoading(true);
      await resendSignUpCode({ username: email });
      setMessage({ text: '確認コードを再送信しました。メールをご確認ください。', type: 'success' });
    } catch (error) {
      setMessage({ text: '確認コードの再送信に失敗しました: ' + error.message, type: 'error' });
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-container">
        <div className="auth-tabs">
          <button 
            className={`auth-tab ${activeTab === 'login' ? 'active' : ''}`}
            onClick={() => {
              if (!loading) setActiveTab('login');
            }}
          >
            ログイン
          </button>
          <button 
            className={`auth-tab ${activeTab === 'signup' ? 'active' : ''}`}
            onClick={() => {
              if (!loading) setActiveTab('signup');
            }}
          >
            新規登録
          </button>
          {activeTab === 'confirm' && (
            <button 
              className={`auth-tab ${activeTab === 'confirm' ? 'active' : ''}`}
            >
              アカウント確認
            </button>
          )}
        </div>

        <form className="auth-form" onSubmit={handleSubmit}>
          {message.text && (
            <div className={`form-message ${message.type}`}>
              {message.text}
            </div>
          )}

          {activeTab !== 'confirm' && (
            <>
              <div className="form-group">
                <label htmlFor="email">メールアドレス</label>
                <input 
                  type="email" 
                  id="email" 
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={loading}
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
                  disabled={loading}
                  required 
                />
                {activeTab === 'signup' && (
                  <small>8文字以上、大文字・小文字・数字を含む必要があります</small>
                )}
              </div>

              {activeTab === 'signup' && (
                <div className="form-group">
                  <label htmlFor="confirmPassword">パスワード（確認）</label>
                  <input 
                    type="password" 
                    id="confirmPassword" 
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    disabled={loading}
                    required 
                  />
                </div>
              )}
            </>
          )}

          {activeTab === 'confirm' && (
            <div className="form-group">
              <label htmlFor="confirmationCode">確認コード</label>
              <input 
                type="text" 
                id="confirmationCode" 
                value={confirmationCode}
                onChange={(e) => setConfirmationCode(e.target.value)}
                disabled={loading}
                required 
              />
              <small>
                メールに送信された6桁の確認コードを入力してください。
                <button 
                  type="button" 
                  onClick={handleResendCode} 
                  disabled={loading}
                  style={{ 
                    background: 'none', 
                    border: 'none', 
                    color: '#ff9900', 
                    textDecoration: 'underline', 
                    cursor: 'pointer',
                    padding: '0 0 0 5px'
                  }}
                >
                  コードを再送信
                </button>
              </small>
            </div>
          )}

          <button type="submit" className="form-button" disabled={loading}>
            {loading ? 'お待ちください...' : (
              activeTab === 'login' ? 'ログイン' : 
              activeTab === 'signup' ? '登録する' : 
              'コードを確認'
            )}
          </button>
        </form>
      </div>
    </div>
  );
}

// ProfilePage Component
function ProfilePage({ user, userAttributes }) {
  const [preorderStatus, setPreorderStatus] = useState('未予約');
  const [loading, setLoading] = useState(false);

  // 予約処理（実際のバックエンドAPIとの連携が必要）
  async function handlePreorder() {
    try {
      setLoading(true);
      
      // ここで実際の予約APIを呼び出す
      // 例: await API.post('epicAdventureApi', '/preorders', { body: { userId: user.userId } });
      
      // 成功したと仮定してステータスを更新（実際の実装では応答に基づいて設定）
      setTimeout(() => {
        setPreorderStatus('予約済み - 発売日にアクセス可能になります');
        setLoading(false);
      }, 1500);
      
    } catch (error) {
      console.error('予約エラー:', error);
      setLoading(false);
    }
  }

  return (
    <div className="profile-page">
      <div className="profile-container">
        <h2>マイページ</h2>
        <div className="profile-info">
          <div style={{ marginBottom: '2rem', padding: '1rem', backgroundColor: '#13132b', borderRadius: '5px' }}>
            <h3 style={{ color: '#ff9900', marginTop: 0 }}>アカウント情報</h3>
            <p><strong>ユーザーID:</strong> {user.userId}</p>
            <p><strong>メールアドレス:</strong> {userAttributes?.email || 'メールアドレスが読み込めません'}</p>
            {userAttributes?.name && <p><strong>お名前:</strong> {userAttributes.name}</p>}
            <p><strong>アカウント作成日:</strong> {new Date(user.signInDetails?.loginTime || Date.now()).toLocaleDateString('ja-JP')}</p>
          </div>
          
          <div style={{ marginBottom: '2rem', padding: '1rem', backgroundColor: '#13132b', borderRadius: '5px' }}>
            <h3 style={{ color: '#ff9900', marginTop: 0 }}>予約状況</h3>
            <p><strong>ステータス:</strong> {preorderStatus}</p>
            <p>EPIC ADVENTUREの発売は2025年5月10日です。</p>
            {preorderStatus === '未予約' ? (
              <button 
                className="cta-button" 
                onClick={handlePreorder}
                disabled={loading}
              >
                {loading ? '処理中...' : 'ゲームを予約する'}
              </button>
            ) : (
              <p style={{ color: '#66ff66' }}>✓ 予約完了！発売をお楽しみに。</p>
            )}
          </div>
          
          <div style={{ marginBottom: '2rem', padding: '1rem', backgroundColor: '#13132b', borderRadius: '5px' }}>
            <h3 style={{ color: '#ff9900', marginTop: 0 }}>アカウント設定</h3>
            <p>アカウント設定の変更は現在準備中です。</p>
            <button className="cta-button" disabled>プロフィールを編集する</button>
          </div>
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