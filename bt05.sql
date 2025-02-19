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

-- 2) Tạo Trigger BEFORE INSERT để kiểm tra số tiền thanh toán
DELIMITER $$
CREATE TRIGGER before_insert_check_payment
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    DECLARE total DECIMAL(10,2);
    SELECT total_amount INTO total FROM orders WHERE order_id = NEW.order_id;
    IF NEW.amount <> total THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Số tiền thanh toán không khớp với tổng đơn hàng!';
    END IF;
END $$
DELIMITER ;

-- 3) Tạo bảng order_logs để lưu lịch sử đơn hàng
CREATE TABLE order_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    old_status ENUM('Pending', 'Completed', 'Cancelled'),
    new_status ENUM('Pending', 'Completed', 'Cancelled'),
    log_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- 4) Tạo Trigger AFTER UPDATE để ghi log khi trạng thái đơn hàng thay đổi
DELIMITER $$
CREATE TRIGGER after_update_order_status
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO order_logs (order_id, old_status, new_status, log_date)
        VALUES (NEW.order_id, OLD.status, NEW.status, NOW());
    END IF;
END $$
DELIMITER ;

-- 5) Tạo Stored Procedure để cập nhật trạng thái đơn hàng và xử lý thanh toán
DELIMITER //
CREATE PROCEDURE sp_update_order_status_with_payment(
    IN p_order_id INT,
    IN p_new_status ENUM('Pending', 'Completed', 'Cancelled'),
    IN p_amount DECIMAL(10,2),
    IN p_payment_method ENUM('Credit Card', 'PayPal', 'Bank Transfer', 'Cash')
)
sp_label: BEGIN
    DECLARE current_status ENUM('Pending', 'Completed', 'Cancelled');

    -- Bắt đầu transaction
    START TRANSACTION;

    -- Kiểm tra trạng thái đơn hàng hiện tại
    SELECT status INTO current_status FROM orders WHERE order_id = p_order_id;

    IF current_status = p_new_status THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Đơn hàng đã có trạng thái này!';
        ROLLBACK;
        LEAVE sp_label; -- Thoát khỏi procedure
    END IF;

    -- Xử lý thanh toán nếu trạng thái mới là 'Completed'
    IF p_new_status = 'Completed' THEN
        INSERT INTO payments (order_id, amount, payment_method, status)
        VALUES (p_order_id, p_amount, p_payment_method, 'Completed');
    END IF;

    -- Cập nhật trạng thái đơn hàng
    UPDATE orders SET status = p_new_status WHERE order_id = p_order_id;

    -- Commit transaction
    COMMIT;
END //
DELIMITER ;

-- 6) Thêm dữ liệu và gọi Stored Procedure
INSERT INTO customers (name, email, phone, address) VALUES ('Nguyen Van A', 'nguyena@gmail.com', '0123456789', 'Hanoi');
INSERT INTO products (name, price, description) VALUES ('Laptop', 1500.00, 'Gaming Laptop');
INSERT INTO orders (customer_id, total_amount) VALUES (1, 1500.00);
INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 1, 1, 1500.00);
CALL sp_update_order_status_with_payment(1, 'Completed', 1500.00, 'Credit Card');

-- 7) Hiển thị lại order_logs
SELECT * FROM order_logs;

-- 8) Xóa tất cả các trigger và transaction
DROP TRIGGER IF EXISTS before_insert_check_payment;
DROP TRIGGER IF EXISTS after_update_order_status;
DROP PROCEDURE IF EXISTS sp_update_order_status_with_payment;
