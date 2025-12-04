SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


-- Logical Database Design — DDL with composite keys
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Talked;
DROP TABLE IF EXISTS Went_To;
DROP TABLE IF EXISTS Worked;
DROP TABLE IF EXISTS Makes;
DROP TABLE IF EXISTS Company;
DROP TABLE IF EXISTS School;
DROP TABLE IF EXISTS Organization;
DROP TABLE IF EXISTS ConnectionC;
DROP TABLE IF EXISTS Connection;
DROP TABLE IF EXISTS UserC;
DROP TABLE IF EXISTS User;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE User (
  Name VARCHAR(100) PRIMARY KEY,
  Address VARCHAR(200)
) ENGINE=InnoDB;

CREATE TABLE UserC (
  Name VARCHAR(100) PRIMARY KEY,
  Type VARCHAR(50),
  Phone_Num VARCHAR(40),
  Email VARCHAR(120),
  CONSTRAINT fk_userc_user FOREIGN KEY (Name) REFERENCES User(Name)
) ENGINE=InnoDB;

CREATE TABLE Connection (
  Name VARCHAR(100) PRIMARY KEY,
  Address VARCHAR(200),
  Relation VARCHAR(80)
) ENGINE=InnoDB;

CREATE TABLE ConnectionC (
  Name VARCHAR(100) PRIMARY KEY,
  Type VARCHAR(50),
  Phone_Num VARCHAR(40),
  Email VARCHAR(120),
  CONSTRAINT fk_connectionc_connection FOREIGN KEY (Name) REFERENCES Connection(Name)
) ENGINE=InnoDB;

CREATE TABLE Organization (
  Name VARCHAR(150),
  Address VARCHAR(200),
  Phone_Num VARCHAR(40),
  Email VARCHAR(120),
  PRIMARY KEY (Name, Address),
  UNIQUE KEY uq_org_name (Name)
) ENGINE=InnoDB;

CREATE TABLE Company (
  Org_N VARCHAR(150),
  Org_A VARCHAR(200),
  Stock VARCHAR(50),
  Num_Employees INT,
  Industry VARCHAR(80),
  PRIMARY KEY (Org_N, Org_A),
  CONSTRAINT fk_company_org FOREIGN KEY (Org_N, Org_A)
    REFERENCES Organization(Name, Address)
) ENGINE=InnoDB;

CREATE TABLE School (
  Org_N VARCHAR(150),
  Org_A VARCHAR(200),
  Enrollment INT,
  Ranking INT,
  PRIMARY KEY (Org_N, Org_A),
  CONSTRAINT fk_school_org FOREIGN KEY (Org_N, Org_A)
    REFERENCES Organization(Name, Address),
  UNIQUE KEY uq_school_orgn (Org_N)
) ENGINE=InnoDB;

CREATE TABLE Makes (
  User_N VARCHAR(100),
  Job VARCHAR(120),
  Start DATE,
  Complete DATE,
  Posted DATETIME,
  Resume BOOLEAN,
  Cover_L BOOLEAN,
  Recruiter VARCHAR(120),
  PRIMARY KEY (User_N, Job, Posted),
  CONSTRAINT fk_makes_user FOREIGN KEY (User_N) REFERENCES User(Name)
) ENGINE=InnoDB;

CREATE TABLE Worked (
  Name VARCHAR(100),
  Org_N VARCHAR(150),
  Start DATE,
  End DATE,
  Role VARCHAR(120),
  Department VARCHAR(120),
  Location VARCHAR(120),
  PRIMARY KEY (Name, Org_N),
  CONSTRAINT fk_worked_user FOREIGN KEY (Name) REFERENCES User(Name),
  CONSTRAINT fk_worked_org FOREIGN KEY (Org_N) REFERENCES Organization(Name)
) ENGINE=InnoDB;

CREATE TABLE Talked (
  User_N VARCHAR(100),
  Connect_N VARCHAR(100),
  Topic VARCHAR(200),
  Method VARCHAR(80),
  Start DATETIME,
  End DATETIME,
  PRIMARY KEY (User_N, Connect_N),
  CONSTRAINT fk_talked_user FOREIGN KEY (User_N) REFERENCES User(Name),
  CONSTRAINT fk_talked_conn FOREIGN KEY (Connect_N) REFERENCES Connection(Name)
) ENGINE=InnoDB;

CREATE TABLE Went_To (
  Name VARCHAR(100),
  School_N VARCHAR(150),
  Type VARCHAR(80),
  Subject VARCHAR(120),
  Graduation DATE,
  PRIMARY KEY (Name, School_N),
  CONSTRAINT fk_wentto_user FOREIGN KEY (Name) REFERENCES User(Name),
  CONSTRAINT fk_wentto_school FOREIGN KEY (School_N) REFERENCES School(Org_N)
) ENGINE=InnoDB;

CREATE INDEX idx_makes_user ON Makes(User_N);
CREATE INDEX idx_worked_org ON Worked(Org_N);
CREATE INDEX idx_talked_conn ON Talked(Connect_N);
CREATE INDEX idx_wentto_school ON Went_To(School_N);
COMMIT;