-- ====================================================================
-- SISTEMA DE GESTIÓN DE E-COMMERCE & ANALÍTICA DE VENTAS (SQL)
-- ====================================================================

-- 1. CREACIÓN DE TABLAS Y RELACIONES
-- --------------------------------------------------------------------

CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
);

CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    precio NUMERIC(10, 2) NOT NULL CHECK (precio >= 0),
    stock INT NOT NULL CHECK (stock >= 0),
    categoria_id INT REFERENCES categorias(id) ON DELETE SET NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    pais VARCHAR(50) DEFAULT 'México',
    registrado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pedidos (
    id SERIAL PRIMARY KEY,
    cliente_id INT REFERENCES clientes(id) ON DELETE CASCADE,
    total NUMERIC(10, 2) DEFAULT 0.00,
    estado VARCHAR(30) DEFAULT 'Completado' CHECK (estado IN ('Pendiente', 'Completado', 'Cancelado')),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detalle_pedidos (
    id SERIAL PRIMARY KEY,
    pedido_id INT REFERENCES pedidos(id) ON DELETE CASCADE,
    producto_id INT REFERENCES productos(id) ON DELETE RESTRICT,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10, 2) NOT NULL
);


-- 2. INSERCIÓN DE DATOS DE PRUEBA (SEEDERS)
-- --------------------------------------------------------------------

INSERT INTO categorias (nombre, descripcion) VALUES 
('Tecnología', 'Gadgets, computadoras y accesorios'),
('Hogar', 'Muebles, decoración y utensilios de cocina'),
('Deportes', 'Ropa deportiva, calzado y equipo de ejercicio');

INSERT INTO productos (nombre, precio, stock, categoria_id) VALUES 
('Laptop Gamer Pro X', 1250.00, 15, 1),
('Mouse Inalámbrico Ergonómico', 45.50, 120, 1),
('Silla de Oficina Ejecutiva', 210.00, 25, 2),
('Cafetera Espresso Automática', 320.00, 30, 2),
('Mat de Yoga Antideslizante', 25.00, 80, 3),
('Set de Mancuernas Ajustables', 150.00, 40, 3);

INSERT INTO clientes (nombre, email, pais) VALUES 
('Carlos Santana', 'carlos.santana@email.com', 'México'),
('Elena Gómez', 'elena.gomez@email.com', 'España'),
('Mateo Rossi', 'mateo.rossi@email.com', 'Argentina'),
('Lucía Fernández', 'lucia.fernandez@email.com', 'Colombia');

-- Pedido 1 (Carlos compra tecnología)
INSERT INTO pedidos (cliente_id, total, estado) VALUES (1, 1295.50, 'Completado');
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario) VALUES 
(1, 1, 1, 1250.00),
(1, 2, 1, 45.50);

-- Pedido 2 (Elena compra para hogar)
INSERT INTO pedidos (cliente_id, total, estado) VALUES (2, 530.00, 'Completado');
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario) VALUES 
(2, 3, 1, 210.00),
(2, 4, 1, 320.00);

-- Pedido 3 (Mateo compra deporte)
INSERT INTO pedidos (cliente_id, total, estado) VALUES (3, 175.00, 'Completado');
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario) VALUES 
(3, 5, 1, 25.00),
(3, 6, 1, 150.00);

-- Pedido 4 (Lucía compra tecnología variada)
INSERT INTO pedidos (cliente_id, total, estado) VALUES (4, 91.00, 'Completado');
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario) VALUES 
(4, 2, 2, 45.50);


-- 3. VISTAS ANALÍTICAS (REPORTES DE NEGOCIO)
-- --------------------------------------------------------------------

-- Vista para conocer el resumen de compras por cliente
CREATE OR REPLACE VIEW v_resumen_clientes AS
SELECT 
    c.id AS cliente_id,
    c.nombre AS cliente,
    c.pais,
    COUNT(p.id) AS total_pedidos,
    COALESCE(SUM(p.total), 0.00) AS dinero_gastado
FROM clientes c
LEFT JOIN pedidos p ON c.id = p.cliente_id
GROUP BY c.id, c.nombre, c.pais;


-- 4. CONSULTA AVANZADA (CON FUNCIONES DE VENTANA / WINDOW FUNCTIONS)
-- --------------------------------------------------------------------
-- Ranking de productos más vendidos utilizando DENSE_RANK()

SELECT 
    p.nombre AS producto,
    cat.nombre AS categoria,
    SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario) AS ingresos_generados,
    DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad) DESC) AS ranking_popularidad
FROM productos p
JOIN categorias cat ON p.categoria_id = cat.id
JOIN detalle_pedidos dp ON p.id = dp.producto_id
GROUP BY p.id, p.nombre, cat.nombre;


-- 5. PROCEDIMIENTO / TRANSACCIÓN PARA REGISTRAR UN NUEVO PEDIDO SEGURA
-- --------------------------------------------------------------------
-- Este bloque demuestra cómo se maneja una transacción robusta con validación de stock

BEGIN;

-- Variables de simulación para el nuevo pedido
DO $$
DECLARE
    v_cliente_id INT := 1;
    v_producto_id INT := 2; -- Mouse Inalámbrico
    v_cantidad INT := 3;
    v_precio NUMERIC(10, 2);
    v_stock_actual INT;
    v_nuevo_pedido_id INT;
BEGIN
    -- 1. Verificar stock disponible y obtener precio
    SELECT precio, stock INTO v_precio, v_stock_actual 
    FROM productos WHERE id = v_producto_id;

    IF v_stock_actual < v_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente. Stock actual: %, Solicitado: %', v_stock_actual, v_cantidad;
    END IF;

    -- 2. Crear el pedido principal
    INSERT INTO pedidos (cliente_id, total, estado) 
    VALUES (v_cliente_id, (v_precio * v_cantidad), 'Completado')
    RETURNING id INTO v_nuevo_pedido_id;

    -- 3. Registrar el detalle del pedido
    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario) 
    VALUES (v_nuevo_pedido_id, v_producto_id, v_cantidad, v_precio);

    -- 4. Descontar el stock del producto
    UPDATE productos 
    SET stock = stock - v_cantidad 
    WHERE id = v_producto_id;

    RAISE NOTICE 'Pedido #% registrado con éxito de forma transaccional.', v_nuevo_pedido_id;
END $$;

COMMIT;
