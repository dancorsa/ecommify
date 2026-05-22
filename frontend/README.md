# Ecommify – Frontend

Interfaz web de la plataforma de e-commerce multi-vendedor, construida con **React 18 + Vite 5**.

## Páginas

| Ruta | Descripción |
|------|-------------|
| `/` | Catálogo de productos con filtros |
| `/product/:id` | Detalle de producto y reseñas |
| `/cart` | Carrito de compras |
| `/checkout` | Proceso de pago |
| `/login` | Inicio de sesión (clientes y vendedores) |
| `/register` | Registro de nuevos usuarios |
| `/seller/inventory` | Panel de inventario del vendedor |

## Desarrollo local

```bash
cd frontend
npm install
npm run dev       # inicia en http://localhost:5173
```

> El proxy de Vite redirige `/api` → `http://localhost:3000` automáticamente.
> Asegúrate de tener el backend corriendo antes de iniciar el frontend.

## Con Docker

El frontend se sirve mediante **nginx** en el puerto `5173`.
Las peticiones a `/api` son proxiadas al servicio `backend` internamente.

```bash
# Desde la raíz del proyecto
docker compose up --build
```

## Stack

- React 18
- Vite 5
- React Router DOM 6
- Axios
- nginx 1.25 (producción)
