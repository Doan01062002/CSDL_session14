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

-- 2) Trigger kiểm tra số lượng hàng trước khi thêm vào order_items
DELIMITER $$
CREATE TRIGGER before_insert_order_items
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE stock INT;
    SELECT stock_quantity INTO stock FROM inventory WHERE product_id = NEW.product_id;
    IF stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không đủ hàng trong kho!';
    END IF;
END$$
DELIMITER ;

-- 3) Trigger cập nhật tổng tiền đơn hàng sau khi thêm sản phẩm
DELIMITER $$
CREATE TRIGGER after_insert_order_items
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders
    SET total_amount = total_amount + (NEW.price * NEW.quantity)
    WHERE order_id = NEW.order_id;
END$$
DELIMITER ;

-- 4) Trigger kiểm tra số lượng hàng trước khi cập nhật order_items
DELIMITER $$
CREATE TRIGGER before_update_order_items
BEFORE UPDATE ON order_items
FOR EACH ROW
BEGIN
    DECLARE stock INT;
    SELECT stock_quantity INTO stock FROM inventory WHERE product_id = NEW.product_id;
    IF stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không đủ hàng trong kho để cập nhật số lượng!';
    END IF;
END$$
DELIMITER ;

-- 5) Trigger cập nhật tổng tiền đơn hàng sau khi cập nhật order_items
DELIMITER $$
CREATE TRIGGER after_update_order_items
AFTER UPDATE ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders
    SET total_amount = total_amount - (OLD.price * OLD.quantity) + (NEW.price * NEW.quantity)
    WHERE order_id = NEW.order_id;
END$$
DELIMITER ;

-- 6) Trigger ngăn chặn xóa đơn hàng đã thanh toán
DELIMITER $$
CREATE TRIGGER before_delete_orders
BEFORE DELETE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status = 'Completed' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể xóa đơn hàng đã thanh toán!';
    END IF;
END$$
DELIMITER ;

-- 7) Trigger hoàn trả số lượng hàng vào kho sau khi xóa sản phẩm khỏi order_items
DELIMITER $$
CREATE TRIGGER after_delete_order_items
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
    UPDATE inventory
    SET stock_quantity = stock_quantity + OLD.quantity
    WHERE product_id = OLD.product_id;
END$$
DELIMITER ;

-- 8) Xóa tất cả các trigger đã tạo
DROP TRIGGER IF EXISTS before_insert_order_items;
DROP TRIGGER IF EXISTS after_insert_order_items;
DROP TRIGGER IF EXISTS before_update_order_items;
DROP TRIGGER IF EXISTS after_update_order_items;
DROP TRIGGER IF EXISTS before_delete_orders;
DROP TRIGGER IF EXISTS after_delete_order_items;
