import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../api';

const CATEGORIES = ['', 'smartphones', 'laptops', 'tablets', 'audio', 'wearables', 'peripherals', 'monitors'];
const CATEGORY_LABELS = {
  '': 'Todas las categorías',
  smartphones: 'Smartphones', laptops: 'Laptops', tablets: 'Tablets',
  audio: 'Audio', wearables: 'Wearables', peripherals: 'Periféricos', monitors: 'Monitores',
};
const CATEGORY_ICONS = {
  smartphones: '📱', laptops: '💻', tablets: '📟', audio: '🎧',
  wearables: '⌚', peripherals: '🖱️', monitors: '🖥️',
};

function Stars({ rating }) {
  const full = Math.round(rating);
  return (
    <span className="stars">
      {'★'.repeat(full)}{'☆'.repeat(5 - full)}
    </span>
  );
}

export default function Catalog() {
  const [products, setProducts] = useState([]);
  const [filters, setFilters] = useState({ category: '', minPrice: '', maxPrice: '', minRating: '' });
  const [loading, setLoading] = useState(false);

  async function fetchProducts(f = filters) {
    setLoading(true);
    try {
      const params = {};
      if (f.category) params.category = f.category;
      if (f.minPrice) params.minPrice = f.minPrice;
      if (f.maxPrice) params.maxPrice = f.maxPrice;
      if (f.minRating) params.minRating = f.minRating;
      const { data } = await api.get('/catalog', { params });
      setProducts(data);
    } catch {
      setProducts([]);
    }
    setLoading(false);
  }

  useEffect(() => { fetchProducts(); }, []);

  function handleFilter(e) {
    e.preventDefault();
    fetchProducts();
  }

  function clearFilters() {
    const empty = { category: '', minPrice: '', maxPrice: '', minRating: '' };
    setFilters(empty);
    fetchProducts(empty);
  }

  const hasFilters = filters.category || filters.minPrice || filters.maxPrice || filters.minRating;

  return (
    <div className="page-wrapper">
      <div className="page-header">
        <h1 className="page-title">Catálogo de productos</h1>
        <p className="page-subtitle">{products.length} productos encontrados</p>
      </div>

      <form onSubmit={handleFilter} className="filter-bar">
        <div className="filter-field" style={{ minWidth: 170 }}>
          <label className="filter-label">Categoría</label>
          <select
            className="filter-input"
            value={filters.category}
            onChange={e => setFilters(f => ({ ...f, category: e.target.value }))}
          >
            {CATEGORIES.map(c => <option key={c} value={c}>{CATEGORY_LABELS[c]}</option>)}
          </select>
        </div>
        <div className="filter-field">
          <label className="filter-label">Precio mín.</label>
          <input
            type="number" placeholder="0" min="0"
            className="filter-input"
            value={filters.minPrice}
            onChange={e => setFilters(f => ({ ...f, minPrice: e.target.value }))}
          />
        </div>
        <div className="filter-field">
          <label className="filter-label">Precio máx.</label>
          <input
            type="number" placeholder="Sin límite" min="0"
            className="filter-input"
            value={filters.maxPrice}
            onChange={e => setFilters(f => ({ ...f, maxPrice: e.target.value }))}
          />
        </div>
        <div className="filter-field">
          <label className="filter-label">Rating mín.</label>
          <input
            type="number" placeholder="1 – 5" min="1" max="5" step="0.1"
            className="filter-input"
            value={filters.minRating}
            onChange={e => setFilters(f => ({ ...f, minRating: e.target.value }))}
          />
        </div>
        <div style={{ display: 'flex', gap: '0.5rem', alignSelf: 'flex-end' }}>
          <button type="submit" className="btn btn-dark">Filtrar</button>
          {hasFilters && (
            <button type="button" className="btn btn-outline" onClick={clearFilters}>Limpiar</button>
          )}
        </div>
      </form>

      {loading ? (
        <div className="spinner">Cargando productos</div>
      ) : products.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon">🔍</div>
          <div className="empty-title">Sin resultados</div>
          <div className="empty-desc">Intenta con otros filtros</div>
          <button className="btn btn-outline" onClick={clearFilters}>Ver todos los productos</button>
        </div>
      ) : (
        <div className="product-grid">
          {products.map(p => (
            <Link to={`/product/${p.id}`} key={p.id} style={{ textDecoration: 'none' }}>
              <div className="product-card">
                <div className="product-img-wrap">
                  {p.images?.[0] ? (
                    <img
                      src={p.images[0]} alt={p.name}
                      className="product-img"
                      onError={e => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex'; }}
                    />
                  ) : null}
                  <div className="product-img-placeholder" style={{ display: p.images?.[0] ? 'none' : 'flex' }}>
                    {CATEGORY_ICONS[p.category] || '📦'}
                  </div>
                </div>

                <div className="product-body">
                  <span className="product-category">
                    {CATEGORY_ICONS[p.category]} {CATEGORY_LABELS[p.category] || p.category}
                  </span>
                  <h3 className="product-name">{p.name}</h3>
                  <div className="product-price">${p.price?.toLocaleString('es-CO')}</div>
                  <div className="product-meta">
                    <span className="product-rating">
                      <Stars rating={p.rating} /> {p.rating}
                    </span>
                    {p.stock === 0
                      ? <span className="badge badge-error">Agotado</span>
                      : p.stock <= 5
                      ? <span className="badge badge-warning">Últimas {p.stock}</span>
                      : <span className="badge badge-success">En stock</span>
                    }
                  </div>
                </div>

                <div className="product-footer">
                  <span style={{ fontSize: '0.82rem', color: 'var(--accent)', fontWeight: 600 }}>
                    Ver detalle →
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
