# Teas N Trees Multi-Brand Backend Integration Guide

This document provides all the necessary information for a frontend agent or developer to integrate with the Teas N Trees / Little H backend.

## 1. System Architecture

### Base URL
`http://localhost:5000/api`

### Multi-Brand Routing
The backend supports multiple brands (`teasntrees`, `littleh`). 
Routes are structured as: `/api/:brand/customer/...` or `/api/:brand/admin/...`

**Important:** The backend also supports **unbranded legacy routes** (e.g., `/api/customer/auth/...`). If the `:brand` segment is missing, it defaults to `teasntrees`.

### Response Format
All API responses follow a standard JSON structure:
```json
{
  "success": true,
  "message": "Optional descriptive message",
  "data": { ... } // Or [ ... ] for lists
}
```

---

## 2. Authentication Flow

The system uses **Firebase Auth** for the initial handshake and **Custom JWTs** for subsequent authenticated requests.

### Flow:
1. **Frontend**: Authenticates user via Firebase (Phone/OTP or Google).
2. **Frontend**: Receives an `idToken` from Firebase.
3. **Frontend**: Sends `idToken` to Backend `/auth/firebase-login` or `/auth/google-login`.
4. **Backend**: Verifies `idToken` with Firebase Admin SDK.
5. **Backend**: Returns a custom `token` (Access Token) and `refreshToken`.
6. **Frontend**: Stores tokens and includes the Access Token in the `Authorization` header for all protected routes.

### Headers:
- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`

---

## 3. Customer API Endpoints

### Authentication
- **POST** `/customer/auth/firebase-login`
  - Body: `{ "idToken": "string", "mobile": "string" }`
  - Note: Used for Phone OTP login verification.
- **POST** `/customer/auth/google-login`
  - Body: `{ "idToken": "string", "email": "string", "name": "string", "photoURL": "string" }`
- **POST** `/customer/auth/complete-profile` (Protected)
  - Body: `{ "name": "string", "address": "string", "email": "string", "location": { "type": "Point", "coordinates": [lng, lat] } }`
- **POST** `/customer/auth/refresh-token`
  - Body: `{ "refreshToken": "string" }`
- **POST** `/customer/auth/logout` (Protected)

### Products & Categories
- **GET** `/customer/products` - List all products (supports `page`, `limit`, `search`, `category` filters).
- **GET** `/customer/products/:id` - Single product details.
- **GET** `/customer/categories` - List all active categories.

### Cart & Orders
- **GET** `/customer/cart` - Get current user's cart.
- **POST** `/customer/cart/add` - Add item to cart.
- **POST** `/customer/cart/checkout` - Convert cart to order.
- **GET** `/customer/orders/my-orders` - List user's order history.
- **GET** `/customer/orders/:id` - Detailed order status and items.

---

## 4. Admin API Endpoints

Admins manage the system across brands.

- **Dashboard**: `GET /admin/dashboard/stats`
- **User Management**: `GET /admin/users`, `PUT /admin/users/:id/role`
- **Catalog Management**:
  - `POST /admin/categories`, `PUT /admin/categories/:id`
  - `POST /admin/products`, `PUT /admin/products/:id`
- **Order Management**: `GET /admin/orders`, `PUT /admin/orders/:id/status`

---

## 5. Rider API Endpoints

Riders handle deliveries. These routes are usually **not** brand-prefixed (`/api/rider/...`).

- **Auth**: `POST /api/rider/auth/verify-otp`
- **Status**: `POST /api/rider/auth/availability` (Toggle Online/Offline)
- **Deliveries**: `GET /api/rider/deliveries/active`, `PUT /api/rider/deliveries/:id/status`

---

## 6. Real-time Integration (Socket.io)

### Connection
```javascript
const socket = io('http://localhost:5000', {
  auth: { token: 'Bearer <access_token>' }
});
```

### Key Events
- `order:status-updated`: Received when an order status changes.
- `rider:location-update`: Real-time tracking of assigned rider.
- `system:data-updated`: Global event to trigger data re-fetch on dashboard.

---

## 7. Frontend Integration Snippet (Axios Interceptor)

```javascript
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('token');
    if (token) config.headers.Authorization = `Bearer ${token}`;

    // Brand logic: extract from URL or use default
    const brand = extractBrandFromUrl() || 'teasntrees';
    
    // Prefix URL if not already prefixed
    if (!config.url.startsWith(`/rider`) && !config.url.startsWith(`/${brand}`)) {
        config.url = `/${brand}${config.url}`;
    }
    return config;
});
```
