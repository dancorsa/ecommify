import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

const STEPS = ['Dirección', 'Pago', 'Confirmación'];

const PAYMENT_OPTIONS = [
  { value: 'credit_card', label: 'Tarjeta de crédito', icon: '💳', desc: 'Visa, Mastercard, Amex' },
  { value: 'debit_card', label: 'Tarjeta débito', icon: '🏦', desc: 'Débito bancario' },
  { value: 'boleto', label: 'Boleto / PSE', icon: '📄', desc: 'Pago en efectivo o PSE' },
];

const ADDR_FIELDS = [
  { name: 'street', label: 'Dirección', placeholder: 'Calle 123 # 45-67', full: true },
  { name: 'city', label: 'Ciudad', placeholder: 'Bogotá' },
  { name: 'state', label: 'Departamento', placeholder: 'Cundinamarca' },
  { name: 'zipCode', label: 'Código postal', placeholder: '110111' },
  { name: 'country', label: 'País', placeholder: 'Colombia' },
];

const emptyAddress = { street: '', city: '', state: '', zipCode: '', country: '' };

export default function Checkout() {
  const [step, setStep] = useState(0);
  const [address, setAddress] = useState(emptyAddress);
  const [payment, setPayment] = useState('credit_card');
  const [order, setOrder] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const cart = JSON.parse(localStorage.getItem('cart') || '[]');
  const subtotal = cart.reduce((s, i) => s + i.price * i.qty, 0);
  const tax = subtotal * 0.19;
  const total = subtotal + tax;

  async function handleConfirm() {
    setError('');
    setLoading(true);
    try {
      const userId = localStorage.getItem('userId');
      const inventory = {};
      cart.forEach(i => { inventory[i.id] = i.stock; });
      const { data } = await api.post('/checkout/orders', { cart, address, payment, userId, inventory });
      setOrder(data);
      localStorage.removeItem('cart');
      window.dispatchEvent(new Event('cartUpdate'));
      setStep(2);
    } catch (err) {
      setError(err.response?.data?.error || 'Error al procesar el pedido');
    } finally {
      setLoading(false);
    }
  }

  const addrComplete = Object.values(address).every(v => v.trim());

  return (
    <div className="page-wrapper" style={{ maxWidth: 860 }}>
      <div className="page-header">
        <h1 className="page-title">Checkout</h1>
      </div>

      <div className="stepper">
        {STEPS.map((s, i) => (
          <>
            <div key={s} className={`step${i === step ? ' active' : i < step ? ' done' : ''}`}>
              <div className="step-circle">{i < step ? '✓' : i + 1}</div>
              <span className="step-label">{s}</span>
            </div>
            {i < STEPS.length - 1 && (
              <div key={`line-${i}`} className={`step-line${i < step ? ' done' : ''}`} />
            )}
          </>
        ))}
      </div>

      <div className="checkout-layout">
        <div>
          {step === 0 && (
            <div className="checkout-panel">
              <div className="section-title">📍 Dirección de envío</div>
              {ADDR_FIELDS.filter(f => f.full).map(f => (
                <div className="form-group" key={f.name}>
                  <label className="form-label">{f.label}</label>
                  <input
                    name={f.name} placeholder={f.placeholder}
                    value={address[f.name]}
                    onChange={e => setAddress(a => ({ ...a, [e.target.name]: e.target.value }))}
                    className="input" required
                  />
                </div>
              ))}
              <div className="form-grid-2">
                {ADDR_FIELDS.filter(f => !f.full).map(f => (
                  <div className="form-group" key={f.name}>
                    <label className="form-label">{f.label}</label>
                    <input
                      name={f.name} placeholder={f.placeholder}
                      value={address[f.name]}
                      onChange={e => setAddress(a => ({ ...a, [e.target.name]: e.target.value }))}
                      className="input" required
                    />
                  </div>
                ))}
              </div>
              <button
                className="btn btn-primary btn-lg"
                onClick={() => setStep(1)}
                disabled={!addrComplete}
                style={{ marginTop: '0.5rem' }}
              >
                Continuar →
              </button>
            </div>
          )}

          {step === 1 && (
            <div className="checkout-panel">
              <div className="section-title">💳 Método de pago</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                {PAYMENT_OPTIONS.map(opt => (
                  <label
                    key={opt.value}
                    className={`payment-option${payment === opt.value ? ' selected' : ''}`}
                    onClick={() => setPayment(opt.value)}
                  >
                    <input
                      type="radio" className="payment-radio"
                      name="payment" value={opt.value}
                      checked={payment === opt.value}
                      onChange={() => setPayment(opt.value)}
                    />
                    <span className="payment-icon">{opt.icon}</span>
                    <div>
                      <div className="payment-label">{opt.label}</div>
                      <div className="payment-desc">{opt.desc}</div>
                    </div>
                  </label>
                ))}
              </div>

              {error && <div className="alert alert-error">⚠️ {error}</div>}

              <div style={{ display: 'flex', gap: '0.75rem', marginTop: '0.5rem' }}>
                <button className="btn btn-outline" onClick={() => setStep(0)}>← Volver</button>
                <button className="btn btn-primary btn-lg" onClick={handleConfirm} disabled={loading} style={{ flex: 1 }}>
                  {loading ? 'Procesando...' : '✓ Confirmar pedido'}
                </button>
              </div>
            </div>
          )}

          {step === 2 && order && (
            <div className="checkout-panel">
              <div className="success-box">
                <div className="success-icon-wrap">✓</div>
                <div className="success-title">¡Pedido confirmado!</div>
                <p className="success-sub">Tu pedido ha sido procesado exitosamente</p>

                <div className="order-detail-card">
                  <div className="order-detail-row">
                    <span>Número de orden</span>
                    <strong>{order.orderId}</strong>
                  </div>
                  <div className="order-detail-row">
                    <span>Método de pago</span>
                    <strong>{PAYMENT_OPTIONS.find(p => p.value === payment)?.label}</strong>
                  </div>
                  <div className="order-detail-row">
                    <span>Total pagado</span>
                    <strong style={{ color: 'var(--accent)' }}>${order.total?.toLocaleString('es-CO', { maximumFractionDigits: 0 })}</strong>
                  </div>
                </div>

                <button className="btn btn-primary btn-lg" onClick={() => navigate('/catalog')}>
                  Seguir comprando
                </button>
              </div>
            </div>
          )}
        </div>

        <div className="cart-summary">
          <div className="summary-title">Tu pedido</div>
          {cart.map(i => (
            <div key={i.id} className="order-summary-item">
              <span style={{ fontSize: '0.83rem' }}>{i.name} <span style={{ color: 'var(--text-muted)' }}>×{i.qty}</span></span>
              <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>${(i.price * i.qty).toLocaleString('es-CO', { maximumFractionDigits: 0 })}</span>
            </div>
          ))}
          <div className="divider" />
          <div className="summary-row"><span>Subtotal</span><span>${subtotal.toLocaleString('es-CO', { maximumFractionDigits: 0 })}</span></div>
          <div className="summary-row"><span>IVA (19%)</span><span>${tax.toLocaleString('es-CO', { maximumFractionDigits: 0 })}</span></div>
          <div className="summary-row total">
            <span>Total</span>
            <span style={{ color: 'var(--accent)' }}>${total.toLocaleString('es-CO', { maximumFractionDigits: 0 })}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
