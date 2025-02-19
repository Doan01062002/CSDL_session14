CREATE DATABASE ss14_second;
USE ss14_second;
-- 1.
CREATE TABLE departments (
    department_id INT PRIMARY KEY AUTO_INCREMENT,
    department_name VARCHAR(255) NOT NULL
);

CREATE TABLE employees (
    employee_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    hire_date DATE NOT NULL,
    department_id INT NOT NULL,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE CASCADE
);

CREATE TABLE attendance (
    attendance_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT NOT NULL,
    check_in_time DATETIME NOT NULL,
    check_out_time DATETIME,
    total_hours DECIMAL(5,2),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

CREATE TABLE salaries (
    employee_id INT PRIMARY KEY,
    base_salary DECIMAL(10,2) NOT NULL,
    bonus DECIMAL(10,2) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

CREATE TABLE salary_history (
    history_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT NOT NULL,
    old_salary DECIMAL(10,2),
    new_salary DECIMAL(10,2),
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

INSERT INTO departments (department_name) VALUES 
('Phòng Nhân Sự'),
('Phòng Kỹ Thuật');

INSERT INTO employees (name, email, phone, hire_date, department_id)
VALUES ('Nguyễn Văn A', 'nguyenvana', '0987654321', '2024-02-17', 1);

INSERT INTO employees (name, email, phone, hire_date, department_id)
VALUES ('Trần Thị B', 'tranthib@company.com', '0912345678', '2024-02-17', 2);

INSERT INTO attendance (employee_id, check_in_time)
VALUES (1, '2024-02-17 08:00:00');

UPDATE attendance
SET check_out_time = '2024-02-17 17:00:00'
WHERE employee_id = 1;

-- 2. Trigger kiểm tra số điện thoại trước khi cập nhật
DELIMITER //
CREATE TRIGGER before_employee_update
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
    IF CHAR_LENGTH(NEW.phone) <> 10 OR NEW.phone NOT REGEXP '^[0-9]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Số điện thoại phải có đúng 10 chữ số.';
    END IF;
END //
DELIMITER ;

-- 4. Trigger tự động tạo thông báo khi nhân viên mới được thêm
DELIMITER //
CREATE TRIGGER after_employee_insert
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
    INSERT INTO notifications (employee_id, message)
    VALUES (NEW.employee_id, CONCAT('Chào mừng ', NEW.name));
END //
DELIMITER ;

-- 5. Stored Procedure để thêm nhân viên mới
DELIMITER //
CREATE PROCEDURE AddNewEmployeeWithPhone(
    IN emp_name VARCHAR(255),
    IN emp_email VARCHAR(255),
    IN emp_phone VARCHAR(20),
    IN emp_hire_date DATE,
    IN emp_department_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Có lỗi xảy ra, quá trình đã bị hủy bỏ.';
    END;
    
    START TRANSACTION;
    
    -- Kiểm tra số điện thoại hợp lệ
    IF CHAR_LENGTH(emp_phone) <> 10 OR emp_phone NOT REGEXP '^[0-9]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Số điện thoại phải có đúng 10 chữ số.';
    END IF;
    
    -- Thêm nhân viên vào bảng employees
    INSERT INTO employees (name, email, phone, hire_date, department_id)
    VALUES (emp_name, emp_email, emp_phone, emp_hire_date, emp_department_id);
    
    COMMIT;
END //
DELIMITER ;
