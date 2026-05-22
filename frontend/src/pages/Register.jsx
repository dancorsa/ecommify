import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import api from '../api';

export default function Register() {
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
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
      const { data } = await api.post('/auth/register', form);
      localStorage.setItem('token', data.token);
      localStorage.setItem('userId', data.user.id);
      setSuccess('¡Registro exitoso! Redirigiendo...');
      setTimeout(() => navigate('/catalog'), 1200);
    } catch (err) {
      setError(err.response?.data?.error || 'Error al registrarse');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-center">
      <div className="auth-card">
        <div className="auth-header">
          <div className="auth-logo">🛍️ Ecommify</div>
          <div className="auth-subtitle">Crea tu cuenta gratis</div>
        </div>

        <h2 className="auth-title">Crear cuenta</h2>

        {error && <div className="alert alert-error" style={{ marginBottom: '1rem' }}>⚠️ {error}</div>}
        {success && <div className="alert alert-success" style={{ marginBottom: '1rem' }}>✓ {success}</div>}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="form-group">
            <label className="form-label">Nombre completo</label>
            <input
              name="name" placeholder="Juan Pérez"
              value={form.name} onChange={handleChange}
              required className="input"
            />
          </div>
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
              name="password" type="password" placeholder="Mín. 8 caracteres, mayúscula y número"
              value={form.password} onChange={handleChange}
              required className="input"
            />
          </div>
          <button type="submit" className="btn btn-primary btn-full btn-lg" disabled={loading} style={{ marginTop: '0.5rem' }}>
            {loading ? 'Creando cuenta...' : 'Registrarse'}
          </button>
        </form>

        <p className="auth-footer">
          ¿Ya tienes cuenta?{' '}
          <Link to="/login" style={{ fontWeight: 600 }}>Inicia sesión</Link>
        </p>
      </div>
    </div>
  );
}
