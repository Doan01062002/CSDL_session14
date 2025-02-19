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

-- 2. Trigger BEFORE INSERT để kiểm tra và chỉnh sửa email
DELIMITER $$
CREATE TRIGGER before_insert_employee
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    IF NEW.email NOT LIKE '%@company.com' THEN
        SET NEW.email = CONCAT(NEW.email, '@company.com');
    END IF;
END $$
DELIMITER ;

-- 3. Trigger AFTER INSERT để tự động thêm lương cho nhân viên mới
DELIMITER $$
CREATE TRIGGER after_insert_employee
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
    INSERT INTO salaries (employee_id, base_salary, bonus)
    VALUES (NEW.employee_id, 10000.00, 0.00);
END $$
DELIMITER ;

-- 4. Trigger AFTER DELETE để lưu lịch sử lương của nhân viên bị xóa
DELIMITER $$
CREATE TRIGGER after_delete_employee
AFTER DELETE ON employees
FOR EACH ROW
BEGIN
    DECLARE last_salary DECIMAL(10,2);
    DECLARE last_bonus DECIMAL(10,2);
    
    -- Lấy lương cuối cùng của nhân viên
    SELECT base_salary, bonus INTO last_salary, last_bonus
    FROM salaries
    WHERE employee_id = OLD.employee_id;
    
    -- Ghi nhận lịch sử lương
    INSERT INTO salary_history (employee_id, old_salary, new_salary, reason)
    VALUES (OLD.employee_id, last_salary, NULL, 'Nhân viên bị xóa');
END $$
DELIMITER ;

-- 5. Trigger BEFORE UPDATE để tự động tính tổng số giờ làm việc
DELIMITER $$
CREATE TRIGGER before_update_attendance
BEFORE UPDATE ON attendance
FOR EACH ROW
BEGIN
    IF NEW.check_out_time IS NOT NULL THEN
        SET NEW.total_hours = TIMESTAMPDIFF(HOUR, NEW.check_in_time, NEW.check_out_time);
    END IF;
END $$
DELIMITER ;

-- 6,
INSERT INTO departments (department_name) VALUES 
('Phòng Nhân Sự'),
('Phòng Kỹ Thuật');

INSERT INTO employees (name, email, phone, hire_date, department_id)
VALUES ('Nguyễn Văn A', 'nguyenvana', '0987654321', '2024-02-17', 1);

select * from employees;

-- 7,
INSERT INTO employees (name, email, phone, hire_date, department_id)
VALUES ('Trần Thị B', 'tranthib@company.com', '0912345678', '2024-02-17', 2);

select * from salaries;

-- 8,
INSERT INTO attendance (employee_id, check_in_time)
VALUES (1, '2024-02-17 08:00:00');

UPDATE attendance
SET check_out_time = '2024-02-17 17:00:00'
WHERE employee_id = 1;

select * from attendance;