curl 'http://127.0.0.1:5076/api/todo_tutorial/__exec_sql'  --data 'query_type=drop%20table&max_rows=50&sql=CREATE%20TABLE%20todo_priority(%0A%09id%20integer%20primary%20key%2C%0A%09description%20varchar%20not%20null%20collate%20nocase_slna%0A)%3B%0A'
curl 'http://127.0.0.1:5076/api/todo_tutorial/__update_metadata' 
curl 'http://127.0.0.1:5076/api/todo_tutorial/__app_menu/.json' --data '_method=PUT&table_view_id=102&label=Prorities&_submit_action_=insert'
