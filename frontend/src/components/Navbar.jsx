import { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';

export default function Navbar() {
  const navigate = useNavigate();
  const location = useLocation();
  const token = localStorage.getItem('token');
  const [cartCount, setCartCount] = useState(0);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const updateCount = () => {
      const cart = JSON.parse(localStorage.getItem('cart') || '[]');
      setCartCount(cart.reduce((s, i) => s + i.qty, 0));
    };
    updateCount();
    window.addEventListener('storage', updateCount);
    window.addEventListener('cartUpdate', updateCount);
    return () => {
      window.removeEventListener('storage', updateCount);
      window.removeEventListener('cartUpdate', updateCount);
    };
  }, []);

  useEffect(() => { setMenuOpen(false); }, [location.pathname]);

  function handleLogout() {
    localStorage.removeItem('token');
    localStorage.removeItem('userId');
    localStorage.removeItem('cart');
    window.dispatchEvent(new Event('cartUpdate'));
    navigate('/login');
  }

  const isActive = (path) => location.pathname === path || location.pathname.startsWith(path + '/');

  return (
    <nav className="navbar" style={{ position: 'relative' }}>
      <Link to="/catalog" className="navbar-brand">
        🛍️ Ecommify
      </Link>

      <ul className={`navbar-links${menuOpen ? ' open' : ''}`}>
        <li>
          <Link to="/catalog" className={`navbar-link${isActive('/catalog') || isActive('/product') ? ' active' : ''}`}>
            Catálogo
          </Link>
        </li>
        <li>
          <Link to="/cart" className={`navbar-link${isActive('/cart') ? ' active' : ''}`}>
            🛒 Carrito
            {cartCount > 0 && <span className="cart-badge">{cartCount}</span>}
          </Link>
        </li>
        <li>
          <Link to="/seller/inventory" className={`navbar-link${isActive('/seller') ? ' active' : ''}`}>
            📦 Inventario
          </Link>
        </li>
        {token ? (
          <li>
            <button onClick={handleLogout} className="navbar-link btn-ghost"
              style={{ background: 'rgba(233,69,96,.15)', color: '#f87171', border: 'none', cursor: 'pointer', fontFamily: 'inherit', fontSize: '0.88rem', fontWeight: 500 }}>
              Salir
            </button>
          </li>
        ) : (
          <>
            <li><Link to="/login" className={`navbar-link${isActive('/login') ? ' active' : ''}`}>Ingresar</Link></li>
            <li>
              <Link to="/register"
                style={{ background: 'var(--accent)', color: '#fff', padding: '0.45rem 1rem', borderRadius: 'var(--radius)', fontSize: '0.88rem', fontWeight: 600, textDecoration: 'none', display: 'inline-block' }}>
                Registro
              </Link>
            </li>
          </>
        )}
      </ul>

      <button className="hamburger" onClick={() => setMenuOpen(o => !o)} aria-label="Menú">
        <span style={{ transform: menuOpen ? 'rotate(45deg) translate(5px, 5px)' : '' }} />
        <span style={{ opacity: menuOpen ? 0 : 1 }} />
        <span style={{ transform: menuOpen ? 'rotate(-45deg) translate(5px, -5px)' : '' }} />
      </button>
    </nav>
  );
}
