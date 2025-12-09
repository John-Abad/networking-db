```bash
# clone / enter project
cd networking-db

# python virtual env
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# create MySQL database (no password version)
mysql -u root -e "CREATE DATABASE IF NOT EXISTS network_assistant;"

# load schema + data + stored procedures
mysql -u root network_assistant < network_assistant_schema.sql
mysql -u root network_assistant < network_assistant_insertions.sql
mysql -u root network_assistant < network_assistant_functions.sql

# if your MySQL root HAS a password, use these instead:
# mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS network_assistant;"
# mysql -u root -p network_assistant < network_assistant_schema.sql
# mysql -u root -p network_assistant < network_assistant_insertions.sql
# mysql -u root -p network_assistant < network_assistant_functions.sql

# optional: environment variables
export DB_HOST=localhost
export DB_NAME=network_assistant
export DB_USER=root
# export DB_PASSWORD=your_password   # only if you set one
export DB_PORT=3306

# run app
python app.py
# then open in browser:
# http://127.0.0.1:5000/
```
