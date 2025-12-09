echo "Тестирование балансировки нагрузки..."
echo "Подключаемся к мастер-ноде..."

vagrant ssh master -c "
    echo 'Отправка 10 запросов через балансировщик...'
    for i in {1..10}; do
        echo -n \"Запрос \$i: \"
        curl -s http://192.168.56.10 | grep -o 'Worker Node\|master-node'
    done
    
    echo ''
    echo 'Статистика распределения:'
    for i in {1..20}; do
        curl -s http://192.168.56.10 | grep -o 'Worker Node\|master-node'
    done | sort | uniq -c | awk '{print \"  \"\$2\": \"\$1\" запросов\"}'
"