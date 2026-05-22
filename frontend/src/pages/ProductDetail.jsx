import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../api';

const CATEGORY_ICONS = {
  smartphones: '📱', laptops: '💻', tablets: '📟', audio: '🎧',
  wearables: '⌚', peripherals: '🖱️', monitors: '🖥️',
};

function Stars({ rating }) {
  const full = Math.round(rating);
  return <span className="stars">{'★'.repeat(full)}{'☆'.repeat(5 - full)}</span>;
}

export default function ProductDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [qty, setQty] = useState(1);
  const [msg, setMsg] = useState('');
  const [imgError, setImgError] = useState(false);

  useEffect(() => {
    api.get(`/catalog/${id}`)
      .then(({ data }) => setProduct(data))
      .catch(() => setProduct(null));
  }, [id]);

  function addToCart() {
    const cart = JSON.parse(localStorage.getItem('cart') || '[]');
    const existing = cart.find(i => i.id === product.id);
    const newQty = (existing?.qty || 0) + qty;

    if (newQty > product.stock) {
      setMsg(`Stock máximo disponible: ${product.stock} unidades`);
      return;
    }

    const updated = existing
      ? cart.map(i => i.id === product.id ? { ...i, qty: newQty } : i)
      : [...cart, { id: product.id, name: product.name, price: product.price, qty, stock: product.stock }];

    localStorage.setItem('cart', JSON.stringify(updated));
    window.dispatchEvent(new Event('cartUpdate'));
    setMsg('¡Producto agregado al carrito!');
    setTimeout(() => setMsg(''), 3000);
  }

  if (!product) {
    return <div className="spinner" style={{ marginTop: '4rem' }}>Cargando producto</div>;
  }

  const specs = product.specs ? Object.entries(product.specs) : [];

  return (
    <div className="page-wrapper">
      <button
        onClick={() => navigate(-1)}
        className="btn btn-ghost btn-sm"
        style={{ marginBottom: '1.25rem', gap: '0.3rem' }}
      >
        ← Volver al catálogo
      </button>

      <div className="detail-layout">
        <div className="detail-img-wrap">
          {product.images?.[0] && !imgError ? (
            <img
              src={product.images[0]} alt={product.name}
              className="detail-img"
              onError={() => setImgError(true)}
            />
          ) : (
            <div className="detail-placeholder">
              {CATEGORY_ICONS[product.category] || '📦'}
            </div>
          )}
        </div>

        <div>
          <div className="detail-category">
            {CATEGORY_ICONS[product.category]} {product.category}
          </div>

          <h1 className="detail-title">{product.name}</h1>

          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', margin: '0.5rem 0' }}>
            <span className="product-rating" style={{ fontSize: '0.9rem' }}>
              <Stars rating={product.rating} /> {product.rating}
            </span>
            {product.available
              ? product.stock <= 5
                ? <span className="badge badge-warning">Últimas {product.stock} unidades</span>
                : <span className="badge badge-success">En stock · {product.stock} disponibles</span>
              : <span className="badge badge-error">Agotado</span>
            }
          </div>

          <div className="detail-price">${product.price?.toLocaleString('es-CO')}</div>

          {product.description && (
            <p className="detail-desc">{product.description}</p>
          )}

          {specs.length > 0 && (
            <>
              <div className="divider" />
              <p style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: '0.5rem' }}>
                Especificaciones
              </p>
              <div className="specs-grid">
                {specs.map(([key, val]) => (
                  <div key={key} className="spec-item">
                    <span className="spec-key">{key}</span>
                    <span className="spec-val">{val}</span>
                  </div>
                ))}
              </div>
            </>
          )}

          {product.available && (
            <>
              <div className="divider" />
              <div className="qty-row">
                <div className="qty-controls">
                  <button className="qty-btn" onClick={() => setQty(q => Math.max(1, q - 1))}>−</button>
                  <div className="qty-value">{qty}</div>
                  <button className="qty-btn" onClick={() => setQty(q => Math.min(product.stock, q + 1))}>+</button>
                </div>
                <button className="btn btn-primary btn-lg" onClick={addToCart}>
                  🛒 Agregar al carrito
                </button>
              </div>
            </>
          )}

          {msg && (
            <div className={`alert ${msg.includes('máximo') ? 'alert-error' : 'alert-success'}`} style={{ marginTop: '0.75rem' }}>
              {msg.includes('máximo') ? '⚠️' : '✓'} {msg}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
