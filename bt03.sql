CREATE DATABASE ss14;
USE ss14;
-- 1,
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) DEFAULT 0,
    status ENUM('Pending', 'Completed', 'Cancelled') DEFAULT 'Pending',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE inventory (
    product_id INT PRIMARY KEY,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE TABLE payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL,
    payment_method ENUM('Credit Card', 'PayPal', 'Bank Transfer', 'Cash') NOT NULL,
    status ENUM('Pending', 'Completed', 'Failed') DEFAULT 'Pending',
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- 2. Stored Procedure: Đặt hàng
DELIMITER //
CREATE PROCEDURE sp_create_order(
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_price DECIMAL(10,2)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_order_id INT;
    
    START TRANSACTION;
    
    -- Kiểm tra tồn kho
    SELECT stock_quantity INTO v_stock FROM inventory WHERE product_id = p_product_id;
    IF v_stock < p_quantity THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không đủ hàng trong kho!';
    END IF;
    
    -- Tạo đơn hàng
    INSERT INTO orders (customer_id, total_amount, status) VALUES (p_customer_id, 0, 'Pending');
    SET v_order_id = LAST_INSERT_ID();
    
    -- Thêm sản phẩm vào đơn hàng
    INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (v_order_id, p_product_id, p_quantity, p_price);
    
    -- Cập nhật tổng tiền của đơn hàng
    UPDATE orders SET total_amount = p_quantity * p_price WHERE order_id = v_order_id;
    
    -- Cập nhật kho hàng
    UPDATE inventory SET stock_quantity = stock_quantity - p_quantity WHERE product_id = p_product_id;
    
    COMMIT;
END //
DELIMITER ;

-- 3. Stored Procedure: Thanh toán đơn hàng
DELIMITER //
CREATE PROCEDURE sp_payment_order(
    IN p_order_id INT,
    IN p_payment_method VARCHAR(20)
)
BEGIN
    DECLARE v_status ENUM('Pending', 'Completed', 'Cancelled');
    DECLARE v_total_amount DECIMAL(10,2);
    
    START TRANSACTION;
    
    -- Kiểm tra trạng thái đơn hàng
    SELECT status, total_amount INTO v_status, v_total_amount FROM orders WHERE order_id = p_order_id;
    IF v_status != 'Pending' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chỉ có thể thanh toán đơn hàng ở trạng thái Pending!';
    END IF;
    
    -- Thêm bản ghi thanh toán
    INSERT INTO payments (order_id, payment_date, amount, payment_method, status) VALUES (p_order_id, NOW(), v_total_amount, p_payment_method, 'Completed');
    
    -- Cập nhật trạng thái đơn hàng
    UPDATE orders SET status = 'Completed' WHERE order_id = p_order_id;
    
    COMMIT;
END //
DELIMITER ;

-- 4. Stored Procedure: Hủy đơn hàng
DELIMITER //
CREATE PROCEDURE sp_cancel_order(
    IN p_order_id INT
)
BEGIN
    DECLARE v_status ENUM('Pending', 'Completed', 'Cancelled');
    
    START TRANSACTION;
    
    -- Kiểm tra trạng thái đơn hàng
    SELECT status INTO v_status FROM orders WHERE order_id = p_order_id;
    IF v_status != 'Pending' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chỉ có thể hủy đơn hàng ở trạng thái Pending!';
    END IF;
    
    -- Hoàn trả số lượng hàng vào kho
    UPDATE inventory AS i
    JOIN order_items AS oi ON i.product_id = oi.product_id
    SET i.stock_quantity = i.stock_quantity + oi.quantity
    WHERE oi.order_id = p_order_id;
    
    -- Xóa sản phẩm khỏi order_items
    DELETE FROM order_items WHERE order_id = p_order_id;
    
    -- Cập nhật trạng thái đơn hàng
    UPDATE orders SET status = 'Cancelled' WHERE order_id = p_order_id;
    
    COMMIT;
END //
DELIMITER ;

-- 6. Xóa tất cả các transaction
DELIMITER //
CREATE PROCEDURE sp_delete_all_transactions()
BEGIN
    START TRANSACTION;
    
    DELETE FROM payments;
    DELETE FROM order_items;
    DELETE FROM orders;
    
    COMMIT;
END //
DELIMITER ;

SET SQL_SAFE_UPDATES = 0;
CALL sp_delete_all_transactions();
SET SQL_SAFE_UPDATES = 1;
