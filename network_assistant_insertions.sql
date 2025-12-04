-- Sample data population for Logical Database Design

INSERT INTO User (Name, Address) VALUES
('Alice Johnson', '10 Oak St, Springfield'),
('Bob Smith', '22 Pine Ave, Metropolis'),
('Carla Nguyen', '5 River Rd, Lakeside'),
('David Lee', '88 Hilltop Dr, Silicon City'),
('Eva Torres', '19 Maple Ln, College Town');

INSERT INTO UserC (Name, Type, Phone_Num, Email) VALUES
('Alice Johnson', 'Premium', '555-1000', 'alice@example.com'),
('Bob Smith', 'Basic', '555-1001', 'bob@example.com');

INSERT INTO Connection (Name, Address, Relation) VALUES
('Grace Kim', '44 Elm St, Metropolis', 'Former Manager'),
('Henry Patel', '300 Cedar Blvd, Springfield', 'Colleague'),
('Irene Chen', '90 Lakeview Dr, Lakeside', 'Recruiter');

INSERT INTO ConnectionC (Name, Type, Phone_Num, Email) VALUES
('Grace Kim', 'LinkedIn', '555-2000', 'grace.kim@corp.com'),
('Henry Patel', 'Email', '555-2001', 'henry.patel@corp.com'),
('Irene Chen', 'Phone', '555-2002', 'irene.chen@agency.com');

INSERT INTO Organization (Name, Address, Phone_Num, Email) VALUES
('Acme Corp', '123 Main St, Springfield', '555-3000', 'info@acmecorp.com'),
('Globex Inc', '500 Market St, Metropolis', '555-3001', 'contact@globex.com'),
('Innotech', '77 Innovation Way, Silicon City', '555-3002', 'hello@innotech.com'),
('State University', '1 College Rd, College Town', '555-4000', 'admissions@stateu.edu');

INSERT INTO Company (Org_N, Org_A, Stock, Num_Employees, Industry) VALUES
('Acme Corp', '123 Main St, Springfield', 'ACME', 250, 'Manufacturing'),
('Globex Inc', '500 Market St, Metropolis', 'GLOB', 800, 'Consulting'),
('Innotech', '77 Innovation Way, Silicon City', 'INNO', 150, 'Technology');

INSERT INTO School (Org_N, Org_A, Enrollment, Ranking) VALUES
('State University', '1 College Rd, College Town', 18000, 75);

INSERT INTO Makes VALUES
('Alice Johnson', 'Software Engineer', '2025-01-05', '2025-01-20',
 '2025-01-01 09:00:00', 1, 1, 'Irene Chen'),
('Alice Johnson', 'Data Analyst', '2025-02-10', '2025-02-25',
 '2025-02-01 10:30:00', 1, 0, 'Grace Kim'),
('David Lee', 'DevOps Engineer', '2025-03-01', '2025-03-15',
 '2025-02-20 14:15:00', 1, 1, 'Henry Patel');

INSERT INTO Worked VALUES
('Alice Johnson', 'Acme Corp', '2022-06-01', '2024-05-31',
 'Junior Engineer','R&D','Springfield'),
('Alice Johnson', 'Globex Inc', '2024-06-01', NULL,
 'Consultant','Technology','Metropolis'),
('Bob Smith', 'Innotech', '2023-01-15', NULL,
 'Data Engineer','Analytics','Silicon City'),
('Carla Nguyen','Acme Corp','2021-03-01','2023-02-28',
 'HR Specialist','HR','Springfield');

INSERT INTO Talked VALUES
('Alice Johnson', 'Grace Kim', 'Career advice', 'Zoom',
 '2025-01-10 15:00:00','2025-01-10 15:45:00'),
('Alice Johnson', 'Irene Chen', 'Job application follow-up', 'Phone',
 '2025-02-05 11:00:00','2025-02-05 11:20:00'),
('Bob Smith', 'Henry Patel', 'Referral request', 'Email',
 '2025-03-02 09:00:00','2025-03-02 09:05:00');

INSERT INTO Went_To VALUES
('Alice Johnson','State University','Undergraduate','Computer Science','2022-05-15'),
('Bob Smith','State University','Undergraduate','Information Systems','2021-05-15'),
('Carla Nguyen','State University','Graduate','Human Resources','2020-05-15');
