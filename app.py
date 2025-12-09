from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
import mysql.connector
from mysql.connector import Error
from datetime import datetime
import os
from functools import wraps

app = Flask(__name__)
# Use an environment variable for the secret key; fall back to a dev-safe default
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'dev-secret-key-change-me')

# Database configuration
# Note: we do NOT store any passwords in the database itself.
# For the DB connection, password is optional and only read from an env var if set.
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'database': os.getenv('DB_NAME', 'network_assistant'),
    'user': os.getenv('DB_USER', 'root'),
    'port': int(os.getenv('DB_PORT', 3306)),
}

db_password = os.getenv('DB_PASSWORD')
if db_password:
    DB_CONFIG['password'] = db_password

def get_db_connection():
    """Create and return a database connection"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        # Ensure stored procedures that perform writes are committed automatically
        connection.autocommit = True
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

def execute_query(query, params=None, fetch=True):
    """Execute a query (or CALL) and return results"""
    connection = get_db_connection()
    if not connection:
        return None
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, params or ())
        
        if fetch:
            # For stored procedures that end with SELECT we want all rows.
            results = cursor.fetchall()
        else:
            connection.commit()
            results = cursor.rowcount
        
        cursor.close()
        connection.close()
        return results
    except Error as e:
        print(f"Error executing query: {e}")
        if connection:
            connection.close()
        return None

@app.route('/')
def index():
    """Homepage with dashboard statistics"""
    stats = {}
    
    # Get user count
    users = execute_query("SELECT COUNT(*) as count FROM User")
    stats['users'] = users[0]['count'] if users else 0
    
    # Get connection count
    connections = execute_query("SELECT COUNT(*) as count FROM Connection")
    stats['connections'] = connections[0]['count'] if connections else 0
    
    # Get company count
    companies = execute_query("SELECT COUNT(*) as count FROM Company")
    stats['companies'] = companies[0]['count'] if companies else 0
    
    # Get school count
    schools = execute_query("SELECT COUNT(*) as count FROM School")
    stats['schools'] = schools[0]['count'] if schools else 0
    
    # Get recent conversations
    recent_talks = execute_query("""
        SELECT t.*, u.Name as UserName, c.Name as ConnectionName
        FROM Talked t
        JOIN User u ON t.User_N = u.Name
        JOIN Connection c ON t.Connect_N = c.Name
        ORDER BY t.Start DESC
        LIMIT 5
    """)
    
    return render_template('index.html', stats=stats, recent_talks=recent_talks or [])

@app.route('/users')
def users():
    """Display all users"""
    users_data = execute_query("""
        SELECT u.*, uc.Type, uc.Phone_Num, uc.Email
        FROM User u
        LEFT JOIN UserC uc ON u.Name = uc.Name
        ORDER BY u.Name
    """)
    return render_template('users.html', users=users_data or [])

@app.route('/connections')
def connections():
    """Display all connections"""
    connections_data = execute_query("""
        SELECT c.*, cc.Type, cc.Phone_Num, cc.Email
        FROM Connection c
        LEFT JOIN ConnectionC cc ON c.Name = cc.Name
        ORDER BY c.Name
    """)
    return render_template('connections.html', connections=connections_data or [])

@app.route('/companies')
def companies():
    """Display all companies"""
    companies_data = execute_query("""
        SELECT o.*, c.Stock, c.Num_Employees, c.Industry
        FROM Organization o
        JOIN Company c ON o.Name = c.Org_N AND o.Address = c.Org_A
        ORDER BY o.Name
    """)
    return render_template('companies.html', companies=companies_data or [])

@app.route('/schools')
def schools():
    """Display all schools"""
    schools_data = execute_query("""
        SELECT o.*, s.Enrollment, s.Ranking
        FROM Organization o
        JOIN School s ON o.Name = s.Org_N AND o.Address = s.Org_A
        ORDER BY o.Name
    """)
    return render_template('schools.html', schools=schools_data or [])

@app.route('/conversations')
def conversations():
    """Display all conversations"""
    conversations_data = execute_query("""
        SELECT t.*, u.Name as UserName, c.Name as ConnectionName, c.Relation
        FROM Talked t
        JOIN User u ON t.User_N = u.Name
        JOIN Connection c ON t.Connect_N = c.Name
        ORDER BY t.Start DESC
    """)
    return render_template('conversations.html', conversations=conversations_data or [])

@app.route('/work-experience')
def work_experience():
    """Display all work experience"""
    work_data = execute_query("""
        SELECT w.*, o.Name as OrgName, o.Address as OrgAddress,
               c.Industry, c.Stock, c.Num_Employees
        FROM Worked w
        JOIN Organization o ON w.Org_N = o.Name
        LEFT JOIN Company c ON o.Name = c.Org_N AND o.Address = c.Org_A
        ORDER BY w.Start DESC
    """)
    return render_template('work_experience.html', work_experience=work_data or [])

@app.route('/applications')
def applications():
    """Display all job applications"""
    applications_data = execute_query("""
        SELECT m.*, u.Name as UserName
        FROM Makes m
        JOIN User u ON m.User_N = u.Name
        ORDER BY m.Posted DESC
    """)
    return render_template('applications.html', applications=applications_data or [])

@app.route('/education')
def education():
    """Display all education records for users and connections."""
    education_data = execute_query("""
        SELECT
            wt.*,
            COALESCE(u.Name, c.Name) AS PersonName,
            CASE
                WHEN u.Name IS NOT NULL THEN 'User'
                WHEN c.Name IS NOT NULL THEN 'Connection'
                ELSE 'Unknown'
            END AS PersonType,
            o.Name AS SchoolName,
            o.Address AS SchoolAddress,
            s.Enrollment,
            s.Ranking
        FROM Went_To wt
        LEFT JOIN User u
          ON wt.Name = u.Name
        LEFT JOIN Connection c
          ON wt.Name = c.Name
        JOIN School s
          ON wt.School_N = s.Org_N
        JOIN Organization o
          ON s.Org_N = o.Name
         AND s.Org_A = o.Address
        ORDER BY wt.Graduation DESC
    """)
    return render_template('education.html', education=education_data or [])

def _opt(value):
    """Helper: return None for empty strings so stored procedures see NULL."""
    if value is None:
        return None
    value = value.strip()
    return value if value != "" else None


def _normalize_dt(value):
    """
    Accept datetime-local strings (YYYY-MM-DDTHH:MM[:SS]) and
    convert them into MySQL-friendly 'YYYY-MM-DD HH:MM:SS'.
    """
    value = _opt(value)
    if not value:
        return None
    if value.endswith('Z'):
        value = value[:-1]
    if 'T' in value:
        value = value.replace('T', ' ')
    # datetime-local often omits seconds; pad if we only have YYYY-MM-DD HH:MM
    if len(value) == 16:
        value = f"{value}:00"
    return value


@app.route('/add/conversation', methods=['GET', 'POST'])
def add_conversation():
    """
    Function 1: Add_Connection_By_Talking

    Unified flow that can:
    - Create a new connection (and optional contact info)
    - Log a conversation
    - Optionally add work experience and/or education
    by calling the Add_Connection_By_Talking stored procedure.
    """
    users = execute_query("SELECT Name FROM User ORDER BY Name") or []
    connections = execute_query("SELECT Name FROM Connection ORDER BY Name") or []

    if request.method == 'POST':
        user_n = request.form.get('user_n')

        # Either pick an existing connection or type a new name.
        existing_connect = _opt(request.form.get('connect_n_existing'))
        new_connect = _opt(request.form.get('connect_n_new'))
        connect_n = existing_connect or new_connect

        if not user_n or not connect_n:
            flash('User and Connection name are required.', 'error')
            return render_template(
                'add_conversation.html',
                users=users,
                connections=connections,
            )

        addr = _opt(request.form.get('addr'))
        relation = _opt(request.form.get('relation'))
        phone = _opt(request.form.get('phone'))
        email = _opt(request.form.get('email'))
        topic = _opt(request.form.get('topic'))
        method = _opt(request.form.get('method'))
        start = _normalize_dt(request.form.get('start'))
        end = _normalize_dt(request.form.get('end'))

        # Optional company / work info
        org_n = _opt(request.form.get('org_n'))
        org_a = _opt(request.form.get('org_a'))
        role = _opt(request.form.get('role'))
        dept = _opt(request.form.get('dept'))
        job_loc = _opt(request.form.get('job_loc'))
        job_start = _opt(request.form.get('job_start'))
        job_end = _opt(request.form.get('job_end'))
        industry = _opt(request.form.get('industry'))
        num_employees = request.form.get('num_employees')
        num_employees = int(num_employees) if _opt(num_employees) else None
        stock = _opt(request.form.get('stock'))

        # Optional school info
        school_n = _opt(request.form.get('school_n'))
        deg_type = _opt(request.form.get('deg_type'))
        subject = _opt(request.form.get('subject'))
        graduation = _opt(request.form.get('graduation'))

        params = (
            user_n,
            connect_n,
            addr,
            relation,
            phone,
            email,
            topic,
            method,
            start,
            end,
            org_n,
            org_a,
            role,
            dept,
            job_loc,
            job_start,
            job_end,
            industry,
            num_employees,
            stock,
            school_n,
            deg_type,
            subject,
            graduation,
        )

        result = execute_query(
            "CALL Add_Connection_By_Talking("
            "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,"
            "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,"
            "%s,%s,%s,%s"
            ")",
            params,
            fetch=True,
        )

        if result is None:
            flash('Error adding connection and conversation.', 'error')
        else:
            flash('Connection and conversation saved successfully.', 'success')

        return redirect(url_for('conversations'))

    return render_template('add_conversation.html', users=users, connections=connections)


@app.route('/delete/connection', methods=['GET', 'POST'])
def delete_connection():
    """Function 2: Delete_Connection – remove a connection and related rows."""
    connections = execute_query("SELECT Name FROM Connection ORDER BY Name") or []
    deleted_summary = None

    if request.method == 'POST':
        connect_n = request.form.get('connect_n')
        if not connect_n:
            flash('Please select a connection to delete.', 'error')
        else:
            rows = execute_query("CALL Delete_Connection(%s)", (connect_n,), fetch=True)
            if rows is None or len(rows) == 0:
                flash('Error deleting connection.', 'error')
            else:
                deleted_summary = rows[0]
                flash(f"Deleted connection '{connect_n}' and related records.", 'success')

    return render_template(
        'delete_connection.html',
        connections=connections,
        deleted_summary=deleted_summary,
    )


@app.route('/update/conversation', methods=['GET', 'POST'])
def update_conversation():
    """Function 3: Update_Conversation – modify an existing conversation."""
    conversations = execute_query("""
        SELECT t.User_N, t.Connect_N, t.Topic, t.Method, t.Start, t.End
        FROM Talked t
        ORDER BY t.Start DESC
    """) or []

    # Pre-format start timestamps for selectors to avoid manual typing errors
    for conv in conversations:
        start_val = conv.get('Start')
        if isinstance(start_val, datetime):
            conv['StartStr'] = start_val.strftime('%Y-%m-%d %H:%M:%S')
        else:
            conv['StartStr'] = str(start_val)

    updated_row = None
    selected_key = ''

    if request.method == 'POST':
        conversation_key = request.form.get('conversation_key')
        if not conversation_key:
            flash('Please select a conversation to update.', 'error')
            return render_template(
                'update_conversation.html',
                conversations=conversations,
                updated_row=updated_row,
                selected_key=selected_key,
            )

        try:
            user_n, connect_n, key_start = conversation_key.split('||')
        except ValueError:
            flash('Invalid conversation selection.', 'error')
            return render_template(
                'update_conversation.html',
                conversations=conversations,
                updated_row=updated_row,
                selected_key=selected_key,
            )

        selected_key = conversation_key

        new_topic = _opt(request.form.get('new_topic'))
        new_method = _opt(request.form.get('new_method'))
        new_start = _normalize_dt(request.form.get('new_start'))
        new_end = _normalize_dt(request.form.get('new_end'))

        rows = execute_query(
            "CALL Update_Conversation(%s,%s,%s,%s,%s,%s,%s)",
            (
                user_n,
                connect_n,
                key_start,
                new_topic,
                new_method,
                new_start,
                new_end,
            ),
            fetch=True,
        )
        if rows:
            updated_row = rows[0]
            flash('Conversation updated.', 'success')
        else:
            flash('No matching conversation found to update.', 'error')

    return render_template(
        'update_conversation.html',
        conversations=conversations,
        updated_row=updated_row,
        selected_key=selected_key,
    )


@app.route('/add/work-experience', methods=['GET', 'POST'])
def add_work_experience():
    """Function 4: Add_Work_Experience – add a new role/experience."""
    # People can be the main user or any existing connection.
    # For simplicity we offer all Connection names and all User names.
    people = execute_query("""
        SELECT Name, 'Connection' AS source FROM Connection
        UNION
        SELECT Name, 'User' AS source FROM User
        ORDER BY Name
    """) or []

    if request.method == 'POST':
        name = request.form.get('name')
        org_n = _opt(request.form.get('org_n'))
        org_a = _opt(request.form.get('org_a'))
        role = _opt(request.form.get('role'))
        start = _opt(request.form.get('start'))
        end = _opt(request.form.get('end'))
        dept = _opt(request.form.get('dept'))
        job_loc = _opt(request.form.get('job_loc'))
        industry = _opt(request.form.get('industry'))
        num_employees = request.form.get('num_employees')
        num_employees = int(num_employees) if _opt(num_employees) else None
        stock = _opt(request.form.get('stock'))

        if not (name and org_n and role and start):
            flash('Name, organization, role, and start date are required.', 'error')
        else:
            rows = execute_query(
                "CALL Add_Work_Experience(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                (
                    name,
                    org_n,
                    org_a,
                    role,
                    start,
                    end,
                    dept,
                    job_loc,
                    industry,
                    num_employees,
                    stock,
                ),
                fetch=True,
            )
            if rows:
                flash('Work experience added.', 'success')
            else:
                flash('Error adding work experience.', 'error')

            return redirect(url_for('work_experience'))

    return render_template('add_work_experience.html', people=people)


@app.route('/search/network', methods=['GET'])
def search_network():
    """Function 5: Search_Connections_By_Company_Industry_Location."""
    user_n = request.args.get('user_n')
    company = _opt(request.args.get('company'))
    industry = _opt(request.args.get('industry'))
    city = _opt(request.args.get('city'))

    users = execute_query("SELECT Name FROM User ORDER BY Name") or []
    results = []

    if user_n:
        results = execute_query(
            "CALL Search_Connections_By_Company_Industry_Location(%s,%s,%s,%s)",
            (
                user_n,
                company,
                industry,
                city,
            ),
            fetch=True,
        ) or []

    return render_template(
        'search_network.html',
        users=users,
        results=results,
        selected_user=user_n,
        company=company or '',
        industry=industry or '',
        city=city or '',
    )


@app.route('/last-contacted')
def last_time_contacted():
    """Function 6: Last_Time_Contacted – show when you last spoke to a connection."""
    user_n = request.args.get('user_n')
    connect_n = request.args.get('connect_n')

    users = execute_query("SELECT Name FROM User ORDER BY Name") or []
    connections = execute_query("SELECT Name FROM Connection ORDER BY Name") or []
    result = None

    if user_n and connect_n:
        rows = execute_query(
            "CALL Last_Time_Contacted(%s,%s)",
            (user_n, connect_n),
            fetch=True,
        )
        if rows:
            result = rows[0]

    return render_template(
        'last_contacted.html',
        users=users,
        connections=connections,
        selected_user=user_n or '',
        selected_connection=connect_n or '',
        result=result,
    )


@app.route('/connections/city', methods=['GET'])
def connections_in_city():
    """Function 7: Connections_In_City – list connections associated with a city."""
    city = _opt(request.args.get('city'))
    user_n = request.args.get('user_n')

    users = execute_query("SELECT Name FROM User ORDER BY Name") or []
    home_results = []
    work_results = []

    if city and user_n:
        # Stored procedure returns two result sets; using two separate SELECTs is simpler here.
        home_results = execute_query(
            """
            SELECT DISTINCT
                C.Name,
                C.Address
            FROM Connection C
            LEFT JOIN Talked T
              ON T.Connect_N = C.Name
             AND T.User_N    = %s
            WHERE C.Address LIKE CONCAT('%%', %s, '%%')
              AND T.User_N IS NOT NULL
            """,
            (user_n, city),
            fetch=True,
        ) or []

        work_results = execute_query(
            """
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
             AND T.User_N    = %s
            WHERE W.Location LIKE CONCAT('%%', %s, '%%')
              AND T.User_N IS NOT NULL
            """,
            (user_n, city),
            fetch=True,
        ) or []

    return render_template(
        'connections_in_city.html',
        users=users,
        city=city or '',
        selected_user=user_n or '',
        home_results=home_results,
        work_results=work_results,
    )

@app.route('/search')
def search():
    """Search functionality"""
    query = request.args.get('q', '')
    if not query:
        return render_template('search.html', results=[])
    
    # Search across multiple tables
    results = []
    
    # Search users
    users = execute_query("""
        SELECT 'User' as type, Name as title, Address as subtitle, NULL as extra
        FROM User
        WHERE Name LIKE %s OR Address LIKE %s
    """, (f'%{query}%', f'%{query}%'))
    if users:
        results.extend(users)
    
    # Search connections
    connections = execute_query("""
        SELECT 'Connection' as type, Name as title, Address as subtitle, Relation as extra
        FROM Connection
        WHERE Name LIKE %s OR Address LIKE %s OR Relation LIKE %s
    """, (f'%{query}%', f'%{query}%', f'%{query}%'))
    if connections:
        results.extend(connections)
    
    # Search companies
    companies = execute_query("""
        SELECT 'Company' as type, o.Name as title, o.Address as subtitle, c.Industry as extra
        FROM Organization o
        JOIN Company c ON o.Name = c.Org_N AND o.Address = c.Org_A
        WHERE o.Name LIKE %s OR c.Industry LIKE %s
    """, (f'%{query}%', f'%{query}%'))
    if companies:
        results.extend(companies)
    
    return render_template('search.html', results=results, query=query)

if __name__ == '__main__':
    # Run without Flask's debug reloader to avoid OS permission issues on some systems
    app.run(debug=False, host='127.0.0.1', port=5000)

