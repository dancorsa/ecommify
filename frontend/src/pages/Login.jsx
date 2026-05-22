import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import api from '../api';

export default function Login() {
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  function handleChange(e) {
    setForm(f => ({ ...f, [e.target.name]: e.target.value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const { data } = await api.post('/auth/login', form);
      localStorage.setItem('token', data.token);
      localStorage.setItem('userId', data.user.id);
      navigate('/catalog');
    } catch (err) {
      setError(err.response?.data?.error || 'Error al iniciar sesión');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-center">
      <div className="auth-card">
        <div className="auth-header">
          <div className="auth-logo">🛍️ Ecommify</div>
          <div className="auth-subtitle">Tu marketplace de confianza</div>
        </div>

        <h2 className="auth-title">Iniciar sesión</h2>

        {error && <div className="alert alert-error" style={{ marginBottom: '1rem' }}>⚠️ {error}</div>}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="form-group">
            <label className="form-label">Correo electrónico</label>
            <input
              name="email" type="email" placeholder="tu@correo.com"
              value={form.email} onChange={handleChange}
              required className="input"
            />
          </div>
          <div className="form-group">
            <label className="form-label">Contraseña</label>
            <input
              name="password" type="password" placeholder="••••••••"
              value={form.password} onChange={handleChange}
              required className="input"
            />
          </div>
          <button type="submit" className="btn btn-primary btn-full btn-lg" disabled={loading} style={{ marginTop: '0.5rem' }}>
            {loading ? 'Ingresando...' : 'Ingresar'}
          </button>
        </form>

        <p className="auth-footer">
          ¿No tienes cuenta?{' '}
          <Link to="/register" style={{ fontWeight: 600 }}>Regístrate gratis</Link>
        </p>

        <div className="divider" />
        <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textAlign: 'center' }}>
          Demo: ana@example.com / Test1234!
        </p>
      </div>
    </div>
  );
}
