.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py test lockers
.\.venv\Scripts\python.exe manage.py test
.\.venv\Scripts\python.exe manage.py runserver   
.\.venv\Scripts\python.exe manage.py makemigrations orders
.\.venv\Scripts\python.exe manage.py makemigrations lockers
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py check

.\.venv\Scripts\python.exe manage.py test orders
.\.venv\Scripts\python.exe manage.py test
#######
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py test orders
.\.venv\Scripts\python.exe manage.py test lockers
.\.venv\Scripts\python.exe manage.py test
.\.venv\Scripts\python.exe manage.py check

.\.venv\Scripts\python.exe manage.py test accounts
.\.venv\Scripts\python.exe manage.py test orders
.\.venv\Scripts\python.exe manage.py test
.\.venv\Scripts\python.exe manage.py check

 

.\.venv\Scripts\python.exe manage.py makemigrations notifications
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py test notifications
.\.venv\Scripts\python.exe manage.py test accounts
.\.venv\Scripts\python.exe manage.py test
.\.venv\Scripts\python.exe manage.py check

.\.venv\Scripts\python.exe manage.py makemigrations audit
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py test lockers
.\.venv\Scripts\python.exe manage.py test orders
.\.venv\Scripts\python.exe manage.py test
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py test audit
.\.venv\Scripts\python.exe manage.py check



****بيشغل كل اختبارات المشروع ****
.\.venv\Scripts\python.exe manage.py test --settings=config.test_settings --keepdb





