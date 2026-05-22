import { useState, useEffect } from 'react';
import api from '../api';

export default function SellerInventory() {
  const [products, setProducts] = useState([]);
  const [sellerId, setSellerId] = useState(localStorage.getItem('userId') || '');
  const [editing, setEditing] = useState({});
  const [msg, setMsg] = useState({});
  const [loading, setLoading] = useState(false);

  async function loadInventory() {
    if (!sellerId.trim()) return;
    setLoading(true);
    try {
      const { data } = await api.get(`/inventory/seller/${sellerId}`);
      setProducts(data);
    } catch {
      setProducts([]);
    }
    setLoading(false);
  }

  useEffect(() => { loadInventory(); }, []);

  async function updateStock(productId) {
    const newStock = Number(editing[productId]);
    if (!Number.isInteger(newStock) || newStock < 0) {
      setMsg(m => ({ ...m, [productId]: { type: 'error', text: 'Stock debe ser un entero ≥ 0' } }));
      return;
    }
    try {
      await api.patch(`/inventory/${productId}`, { newStock, sellerId });
      setMsg(m => ({ ...m, [productId]: { type: 'success', text: 'Actualizado' } }));
      setTimeout(() => setMsg(m => { const n = { ...m }; delete n[productId]; return n; }), 2500);
      loadInventory();
    } catch (err) {
      setMsg(m => ({ ...m, [productId]: { type: 'error', text: err.response?.data?.error || 'Error al actualizar' } }));
    }
  }

  return (
    <div className="page-wrapper">
      <div className="page-header">
        <h1 className="page-title">Panel de Inventario</h1>
        <p className="page-subtitle">Gestiona el stock de tus productos</p>
      </div>

      <div className="card" style={{ padding: '1.25rem', marginBottom: '1.5rem', display: 'flex', gap: '0.75rem', alignItems: 'flex-end', flexWrap: 'wrap' }}>
        <div className="form-group" style={{ flex: 1, minWidth: 240 }}>
          <label className="form-label">ID del Vendedor</label>
          <input
            className="input"
            value={sellerId}
            onChange={e => setSellerId(e.target.value)}
            placeholder="Ingresa tu Seller ID"
            onKeyDown={e => e.key === 'Enter' && loadInventory()}
          />
        </div>
        <button className="btn btn-dark" onClick={loadInventory} disabled={!sellerId.trim()}>
          Cargar inventario
        </button>
      </div>

      {loading ? (
        <div className="spinner">Cargando inventario</div>
      ) : products.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon">📦</div>
          <div className="empty-title">Sin productos</div>
          <div className="empty-desc">
            {sellerId ? 'No se encontraron productos para este vendedor.' : 'Ingresa tu Seller ID y presiona Cargar.'}
          </div>
          {!sellerId && (
            <div className="alert alert-info" style={{ maxWidth: 380, margin: '0 auto' }}>
              💡 Demo: usa <strong>a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11</strong>
            </div>
          )}
        </div>
      ) : (
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ padding: '1rem 1.25rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontWeight: 700, fontSize: '0.95rem' }}>{products.length} productos</span>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <span className="badge badge-success">{products.filter(p => !p.isOutOfStock).length} disponibles</span>
              <span className="badge badge-error">{products.filter(p => p.isOutOfStock).length} agotados</span>
            </div>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Producto</th>
                  <th>Stock actual</th>
                  <th>Estado</th>
                  <th>Nuevo stock</th>
                  <th>Acción</th>
                </tr>
              </thead>
              <tbody>
                {products.map(p => (
                  <tr key={p.id}>
                    <td style={{ fontWeight: 600 }}>{p.name}</td>
                    <td>
                      <span style={{ fontWeight: 700, fontSize: '1rem' }}>{p.stock}</span>
                    </td>
                    <td>
                      {p.isOutOfStock
                        ? <span className="badge badge-error">Agotado</span>
                        : p.stock <= 5
                        ? <span className="badge badge-warning">Stock bajo</span>
                        : <span className="badge badge-success">Disponible</span>
                      }
                    </td>
                    <td>
                      <input
                        type="number" min="0"
                        className="stock-input"
                        value={editing[p.id] ?? p.stock}
                        onChange={e => setEditing(ed => ({ ...ed, [p.id]: e.target.value }))}
                        onKeyDown={e => e.key === 'Enter' && updateStock(p.id)}
                      />
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <button className="btn btn-primary btn-sm" onClick={() => updateStock(p.id)}>
                          Actualizar
                        </button>
                        {msg[p.id] && (
                          <span style={{
                            fontSize: '0.78rem', fontWeight: 600,
                            color: msg[p.id].type === 'success' ? 'var(--success)' : 'var(--error)'
                          }}>
                            {msg[p.id].type === 'success' ? '✓' : '⚠'} {msg[p.id].text}
                          </span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
