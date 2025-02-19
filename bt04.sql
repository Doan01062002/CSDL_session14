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

-- 2) Tạo thủ tục IncreaseSalary
DELIMITER $$
CREATE PROCEDURE IncreaseSalary(
    IN emp_id INT,
    IN new_salary DECIMAL(10,2),
    IN reason TEXT
)
BEGIN
    DECLARE old_salary DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi xảy ra trong quá trình cập nhật lương!';
    END;
    
    START TRANSACTION;
    
    -- Kiểm tra nhân viên có tồn tại không
    SELECT base_salary INTO old_salary FROM salaries WHERE employee_id = emp_id;
    IF old_salary IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nhân viên không tồn tại!';
    END IF;
    
    -- Lưu lịch sử lương
    INSERT INTO salary_history (employee_id, old_salary, new_salary, reason)
    VALUES (emp_id, old_salary, new_salary, reason);
    
    -- Cập nhật lương mới
    UPDATE salaries SET base_salary = new_salary WHERE employee_id = emp_id;
    
    COMMIT;
END $$
DELIMITER ;

-- 3) Gọi thủ tục IncreaseSalary
CALL IncreaseSalary(1, 5000.00, 'Tăng lương định kỳ');

-- 4) Tạo thủ tục DeleteEmployee
DELIMITER $$
CREATE PROCEDURE DeleteEmployee(
    IN emp_id INT
)
BEGIN
    DECLARE emp_exists INT;
    DECLARE old_salary DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi xảy ra trong quá trình xóa nhân viên!';
    END;
    
    START TRANSACTION;
    
    -- Kiểm tra nhân viên có tồn tại không
    SELECT COUNT(*) INTO emp_exists FROM employees WHERE employee_id = emp_id;
    IF emp_exists = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nhân viên không tồn tại!';
    END IF;
    
    -- Lưu lịch sử lương trước khi xóa
    SELECT base_salary INTO old_salary FROM salaries WHERE employee_id = emp_id;
    IF old_salary IS NOT NULL THEN
        INSERT INTO salary_history (employee_id, old_salary, new_salary, reason)
        VALUES (emp_id, old_salary, NULL, 'Xóa nhân viên');
    END IF;
    
    -- Xóa thông tin lương
    DELETE FROM salaries WHERE employee_id = emp_id;
    
    -- Xóa nhân viên
    DELETE FROM employees WHERE employee_id = emp_id;
    
    COMMIT;
END $$
DELIMITER ;

-- 5) Gọi thủ tục xóa nhân viên có emp_id = 2
CALL DeleteEmployee(2);
