DELIMITER $$

/* =========================================================
   Function 1: Add_Connection_By_Talking
   ========================================================= */
DROP PROCEDURE IF EXISTS Add_Connection_By_Talking;
CREATE PROCEDURE Add_Connection_By_Talking (
    IN p_User_N       VARCHAR(100),
    IN p_Connect_N    VARCHAR(100),
    IN p_Addr         VARCHAR(200),
    IN p_Relation     VARCHAR(80),
    IN p_Phone        VARCHAR(40),
    IN p_Email        VARCHAR(120),
    IN p_Topic        VARCHAR(200),
    IN p_Method       VARCHAR(80),
    IN p_StartTS      DATETIME,
    IN p_EndTS        DATETIME,
    -- Job info (optional)
    IN p_Org_N        VARCHAR(150),
    IN p_Org_A        VARCHAR(200),
    IN p_Role         VARCHAR(120),
    IN p_Dept         VARCHAR(120),
    IN p_JobLoc       VARCHAR(120),
    IN p_JobStart     DATE,
    IN p_JobEnd       DATE,
    IN p_Industry     VARCHAR(80),
    IN p_Num_Employees INT,
    IN p_Stock        VARCHAR(50),
    -- School info (optional)
    IN p_School_N     VARCHAR(150),
    IN p_DegType      VARCHAR(80),
    IN p_Subject      VARCHAR(120),
    IN p_Graduation   DATE
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    -- 1. Verify User exists
    SELECT COUNT(*) INTO v_exists
    FROM User
    WHERE Name = p_User_N;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User does not exist';
    END IF;

    -- 2. Add connection if not found
    SELECT COUNT(*) INTO v_exists
    FROM Connection
    WHERE Name = p_Connect_N;

    IF v_exists = 0 THEN
        INSERT INTO Connection (Name, Address, Relation)
        VALUES (p_Connect_N, p_Addr, p_Relation);
    END IF;

    -- 3. Add connection contact info if provided
    IF p_Phone IS NOT NULL OR p_Email IS NOT NULL THEN
        INSERT INTO ConnectionC (Name, Type, Phone_Num, Email)
        VALUES (p_Connect_N, 'personal', p_Phone, p_Email)
        ON DUPLICATE KEY UPDATE
            Type      = VALUES(Type),
            Phone_Num = VALUES(Phone_Num),
            Email     = VALUES(Email);
    END IF;

    -- 4. Log the conversation
    INSERT INTO Talked (User_N, Connect_N, Topic, Method, Start, End)
    VALUES (p_User_N, p_Connect_N, p_Topic, p_Method, p_StartTS, p_EndTS);

    /* 5. If job info provided (Org_N not NULL) */
    IF p_Org_N IS NOT NULL THEN
        -- 5a. Ensure organization exists
        SELECT COUNT(*) INTO v_exists
        FROM Organization
        WHERE Name = p_Org_N;

        IF v_exists = 0 THEN
            INSERT INTO Organization (Name, Address, Phone_Num, Email)
            VALUES (p_Org_N, COALESCE(p_Org_A, 'Unknown address'), NULL, NULL);
        END IF;

        -- 5b. If company attributes given, upsert company
        IF p_Industry IS NOT NULL OR p_Num_Employees IS NOT NULL OR p_Stock IS NOT NULL THEN
            INSERT INTO Company (Org_N, Org_A, Stock, Num_Employees, Industry)
            VALUES (p_Org_N, COALESCE(p_Org_A, 'Unknown address'), p_Stock, p_Num_Employees, p_Industry)
            ON DUPLICATE KEY UPDATE
                Org_A         = VALUES(Org_A),
                Stock         = VALUES(Stock),
                Num_Employees = VALUES(Num_Employees),
                Industry      = VALUES(Industry);
        END IF;

        -- 5c. Insert Worked row for the connection at this company
        INSERT INTO Worked (Name, Org_N, Start, End, Role, Department, Location)
        VALUES (p_Connect_N, p_Org_N, p_JobStart, p_JobEnd, p_Role, p_Dept, p_JobLoc);
    END IF;

    /* 6. If school info provided (School_N not NULL) */
    IF p_School_N IS NOT NULL THEN
        -- 6a. Ensure school org exists
        SELECT COUNT(*) INTO v_exists
        FROM Organization
        WHERE Name = p_School_N;

        IF v_exists = 0 THEN
            INSERT INTO Organization (Name, Address, Phone_Num, Email)
            VALUES (p_School_N, COALESCE(p_Org_A, 'Unknown address'), NULL, NULL);
        END IF;

        -- 6b. Upsert School row
        INSERT INTO School (Org_N, Org_A, Enrollment, Ranking)
        VALUES (p_School_N, COALESCE(p_Org_A, 'Unknown address'), NULL, NULL)
        ON DUPLICATE KEY UPDATE
            Org_A = VALUES(Org_A);
        
        -- 6c. Insert Went_To for this connection
        INSERT INTO Went_To (Name, School_N, Type, Subject, Graduation)
        VALUES (p_Connect_N, p_School_N, p_DegType, p_Subject, p_Graduation);
    END IF;

    -- 7. Display confirmation (we return the new connection and conversation info)
    SELECT p_Connect_N AS NewConnection,
           p_User_N    AS UserName,
           p_StartTS   AS ConversationStart,
           p_EndTS     AS ConversationEnd;
END$$


/* =========================================================
   Function 2: Delete_Connection
   ========================================================= */
DROP PROCEDURE IF EXISTS Delete_Connection;
CREATE PROCEDURE Delete_Connection (
    IN p_Connect_N VARCHAR(100)
)
BEGIN
    DECLARE v_deleted_talked INT DEFAULT 0;
    DECLARE v_deleted_worked INT DEFAULT 0;
    DECLARE v_deleted_went   INT DEFAULT 0;
    DECLARE v_deleted_conc   INT DEFAULT 0;
    DECLARE v_deleted_conn   INT DEFAULT 0;

    -- 1) Delete related Talked rows
    DELETE FROM Talked WHERE Connect_N = p_Connect_N;
    SET v_deleted_talked = ROW_COUNT();

    -- 2) Delete related Worked rows
    DELETE FROM Worked WHERE Name = p_Connect_N;
    SET v_deleted_worked = ROW_COUNT();

    -- 3) Delete related Went_To rows
    DELETE FROM Went_To WHERE Name = p_Connect_N;
    SET v_deleted_went = ROW_COUNT();

    -- 4) Delete ConnectionC rows
    DELETE FROM ConnectionC WHERE Name = p_Connect_N;
    SET v_deleted_conc = ROW_COUNT();

    -- 5) Delete from Connection
    DELETE FROM Connection WHERE Name = p_Connect_N;
    SET v_deleted_conn = ROW_COUNT();

    -- 6) Optional: clean up orphan organizations/companies/schools
    -- This is simplistic and may be adjusted for your logic.
    DELETE O
    FROM Organization O
    LEFT JOIN Worked W      ON W.Org_N = O.Name
    LEFT JOIN Company Co    ON Co.Org_N = O.Name
    LEFT JOIN School Sc     ON Sc.Org_N = O.Name
    LEFT JOIN Went_To WT    ON WT.School_N = O.Name
    WHERE W.Org_N IS NULL
      AND Co.Org_N IS NULL
      AND Sc.Org_N IS NULL
      AND WT.School_N IS NULL;

    -- 7) Show number of records deleted
    SELECT v_deleted_talked AS TalkedDeleted,
           v_deleted_worked AS WorkedDeleted,
           v_deleted_went   AS WentToDeleted,
           v_deleted_conc   AS ConnectionCDeleted,
           v_deleted_conn   AS ConnectionDeleted,
           (v_deleted_talked + v_deleted_worked + v_deleted_went + 
            v_deleted_conc + v_deleted_conn) AS TotalDeleted;
END$$


/* =========================================================
   Function 3: Update_Conversation
   ========================================================= */
DROP PROCEDURE IF EXISTS Update_Conversation;
CREATE PROCEDURE Update_Conversation (
    IN p_User_N      VARCHAR(100),
    IN p_Connect_N   VARCHAR(100),
    IN p_KeyStartTS  DATETIME,
    IN p_NewTopic    VARCHAR(200),
    IN p_NewMethod   VARCHAR(80),
    IN p_NewStartTS  DATETIME,
    IN p_NewEndTS    DATETIME
)
BEGIN
    -- Update only provided fields via COALESCE
    UPDATE Talked
    SET Topic  = COALESCE(p_NewTopic, Topic),
        Method = COALESCE(p_NewMethod, Method),
        Start  = COALESCE(p_NewStartTS, Start),
        End    = COALESCE(p_NewEndTS, End)
    WHERE User_N    = p_User_N
      AND Connect_N = p_Connect_N
      AND Start     = p_KeyStartTS;

    -- Display updated conversation
    SELECT *
    FROM Talked
    WHERE User_N    = p_User_N
      AND Connect_N = p_Connect_N
      AND Start     = COALESCE(p_NewStartTS, p_KeyStartTS);
END$$


/* =========================================================
   Function 4: Add_Work_Experience
   ========================================================= */
DROP PROCEDURE IF EXISTS Add_Work_Experience;
CREATE PROCEDURE Add_Work_Experience (
    IN p_Name          VARCHAR(100),
    IN p_Org_N         VARCHAR(150),
    IN p_Org_A         VARCHAR(200),
    IN p_Role          VARCHAR(120),
    IN p_Start         DATE,
    IN p_End           DATE,
    IN p_Dept          VARCHAR(120),
    IN p_JobLoc        VARCHAR(120),
    IN p_Industry      VARCHAR(80),
    IN p_Num_Employees INT,
    IN p_Stock         VARCHAR(50)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    -- 1) Confirm Name exists in Connection, or add it
    SELECT COUNT(*) INTO v_exists
    FROM Connection
    WHERE Name = p_Name;

    IF v_exists = 0 THEN
        INSERT INTO Connection (Name, Address, Relation)
        VALUES (p_Name, NULL, 'unknown');
    END IF;

    -- 2) Ensure Organization exists
    SELECT COUNT(*) INTO v_exists
    FROM Organization
    WHERE Name = p_Org_N;

    IF v_exists = 0 THEN
        INSERT INTO Organization (Name, Address, Phone_Num, Email)
        VALUES (p_Org_N, COALESCE(p_Org_A, 'Unknown address'), NULL, NULL);
    END IF;

    -- 3) If company attributes provided, upsert Company
    IF p_Industry IS NOT NULL OR p_Num_Employees IS NOT NULL OR p_Stock IS NOT NULL THEN
        INSERT INTO Company (Org_N, Org_A, Stock, Num_Employees, Industry)
        VALUES (p_Org_N, COALESCE(p_Org_A, 'Unknown address'),
                p_Stock, p_Num_Employees, p_Industry)
        ON DUPLICATE KEY UPDATE
            Org_A         = VALUES(Org_A),
            Stock         = VALUES(Stock),
            Num_Employees = VALUES(Num_Employees),
            Industry      = VALUES(Industry);
    END IF;

    -- 4) Insert new Worked row
    INSERT INTO Worked (Name, Org_N, Start, End, Role, Department, Location)
    VALUES (p_Name, p_Org_N, p_Start, p_End, p_Role, p_Dept, p_JobLoc);

    -- 5) Show the new employment row
    SELECT *
    FROM Worked
    WHERE Name  = p_Name
      AND Org_N = p_Org_N
      AND Start = p_Start;
END$$


/* =========================================================
   Function 5: Search_Connections_By_Company_Industry_Location
   ========================================================= */
DROP PROCEDURE IF EXISTS Search_Connections_By_Company_Industry_Location;
CREATE PROCEDURE Search_Connections_By_Company_Industry_Location (
    IN p_User_N   VARCHAR(100),
    IN p_Company  VARCHAR(150),
    IN p_Industry VARCHAR(80),
    IN p_City     VARCHAR(120)
)
BEGIN
    /*
      Pass NULL for any filter you don't want to apply.
      For example: p_Company = NULL means "any company".
    */
    SELECT DISTINCT
        C.Name,
        W.Role,
        O.Name      AS Company,
        Co.Industry,
        W.Location
    FROM Connection C
    JOIN Worked W
      ON C.Name = W.Name
    JOIN Organization O
      ON W.Org_N = O.Name
    LEFT JOIN Company Co
      ON Co.Org_N = O.Name
    JOIN Talked T
      ON T.Connect_N = C.Name
     AND T.User_N    = p_User_N
    WHERE (p_Company  IS NULL OR O.Name      LIKE CONCAT('%', p_Company, '%'))
      AND (p_Industry IS NULL OR Co.Industry LIKE CONCAT('%', p_Industry, '%'))
      AND (p_City     IS NULL OR W.Location  LIKE CONCAT('%', p_City, '%'))
    ORDER BY C.Name, Company, W.Role;
END$$


/* =========================================================
   Function 6: Last_Time_Contacted
   ========================================================= */
DROP PROCEDURE IF EXISTS Last_Time_Contacted;
CREATE PROCEDURE Last_Time_Contacted (
    IN p_User_N    VARCHAR(100),
    IN p_Connect_N VARCHAR(100)
)
BEGIN
    DECLARE v_LastContact DATETIME;

    SELECT MAX(End) INTO v_LastContact
    FROM Talked
    WHERE User_N    = p_User_N
      AND Connect_N = p_Connect_N;

    IF v_LastContact IS NULL THEN
        SELECT 'No conversations yet.' AS Message, NULL AS LastContact;
    ELSE
        SELECT 'OK' AS Status, v_LastContact AS LastContact;
    END IF;
END$$


/* =========================================================
   Function 7: Connections_In_City
   ========================================================= */
DROP PROCEDURE IF EXISTS Connections_In_City;
CREATE PROCEDURE Connections_In_City (
    IN p_City   VARCHAR(120),
    IN p_User_N VARCHAR(100)
)
BEGIN
    -- A. Home address path (only connections you've actually talked to)
    SELECT DISTINCT
        C.Name,
        C.Address
    FROM Connection C
    LEFT JOIN Talked T
      ON T.Connect_N = C.Name
     AND T.User_N    = p_User_N
    WHERE C.Address LIKE CONCAT('%', p_City, '%')
      AND T.User_N IS NOT NULL;

    -- B. Work location path (also restricted to your network)
    SELECT DISTINCT
        C.Name,
        W.Location,
        W.Role,
        W.Org_N AS Company
    FROM Connection C
    JOIN Worked W
      ON W.Name = C.Name
    LEFT JOIN Talked T
      ON T.Connect_N = C.Name
     AND T.User_N    = p_User_N
    WHERE W.Location LIKE CONCAT('%', p_City, '%')
      AND T.User_N IS NOT NULL;
END$$

DELIMITER ;
