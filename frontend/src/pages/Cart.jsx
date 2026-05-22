import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';

export default function Cart() {
  const [cart, setCart] = useState([]);
  const navigate = useNavigate();

  useEffect(() => {
    setCart(JSON.parse(localStorage.getItem('cart') || '[]'));
  }, []);

  function updateQty(id, newQty) {
    const item = cart.find(i => i.id === id);
    if (newQty < 1) return;
    if (newQty > item.stock) {
      alert(`Stock máximo disponible: ${item.stock} unidades`);
      return;
    }
    const updated = cart.map(i => i.id === id ? { ...i, qty: newQty } : i);
    setCart(updated);
    localStorage.setItem('cart', JSON.stringify(updated));
    window.dispatchEvent(new Event('cartUpdate'));
  }

  function removeItem(id) {
    const updated = cart.filter(i => i.id !== id);
    setCart(updated);
    localStorage.setItem('cart', JSON.stringify(updated));
    window.dispatchEvent(new Event('cartUpdate'));
  }

  const subtotal = cart.reduce((s, i) => s + i.price * i.qty, 0);
  const tax = subtotal * 0.19;
  const total = subtotal + tax;

  if (cart.length === 0) {
    return (
      <div className="page-wrapper">
        <h1 className="page-title" style={{ marginBottom: '2rem' }}>Carrito de compras</h1>
        <div className="empty-state">
          <div className="empty-icon">🛒</div>
          <div className="empty-title">Tu carrito está vacío</div>
          <div className="empty-desc">Agrega productos desde el catálogo para comenzar</div>
          <Link to="/catalog" className="btn btn-primary">Ver catálogo</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page-wrapper">
      <div className="page-header">
        <h1 className="page-title">Carrito de compras</h1>
        <p className="page-subtitle">{cart.length} producto{cart.length !== 1 ? 's' : ''}</p>
      </div>

      <div className="cart-layout">
        <div className="cart-table-wrap">
          <table className="cart-table">
            <thead>
              <tr>
                <th>Producto</th>
                <th>Precio unit.</th>
                <th>Cantidad</th>
                <th>Subtotal</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {cart.map(item => (
                <tr key={item.id}>
                  <td>
                    <Link to={`/product/${item.id}`} className="cart-item-name" style={{ color: 'var(--text)' }}>
                      {item.name}
                    </Link>
                  </td>
                  <td style={{ color: 'var(--text-muted)' }}>${item.price.toLocaleString('es-CO')}</td>
                  <td>
                    <div className="cart-qty-controls">
                      <button className="cart-qty-btn" onClick={() => updateQty(item.id, item.qty - 1)}>−</button>
                      <div className="cart-qty-val">{item.qty}</div>
                      <button className="cart-qty-btn" onClick={() => updateQty(item.id, item.qty + 1)}>+</button>
                    </div>
                  </td>
                  <td style={{ fontWeight: 700 }}>${(item.price * item.qty).toLocaleString('es-CO')}</td>
                  <td>
                    <button className="cart-remove" onClick={() => removeItem(item.id)} title="Eliminar">✕</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="cart-summary">
          <div className="summary-title">Resumen del pedido</div>
          <div className="summary-row">
            <span>Subtotal</span>
            <span>${subtotal.toLocaleString('es-CO', { maximumFractionDigits: 0 })}</span>
          </div>
          <div className="summary-row">
            <span>IVA (19%)</span>
            <span>${tax.toLocaleString('es-CO', { maximumFractionDigits: 0 })}</span>
          </div>
          <div className="summary-row total">
            <span>Total</span>
            <span style={{ color: 'var(--accent)' }}>${total.toLocaleString('es-CO', { maximumFractionDigits: 0 })}</span>
          </div>
          <button
            className="btn btn-primary btn-full btn-lg"
            style={{ marginTop: '1.25rem' }}
            onClick={() => navigate('/checkout')}
          >
            Ir al checkout →
          </button>
          <Link to="/catalog" className="btn btn-ghost btn-full" style={{ marginTop: '0.5rem', justifyContent: 'center' }}>
            ← Seguir comprando
          </Link>
        </div>
      </div>
    </div>
  );
}
