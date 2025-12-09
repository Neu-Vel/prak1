#!/bin/bash

echo "=== СЦЕНАРИЙ ДЕМОНСТРАЦИИ КЛАСТЕРА ==="
echo ""
echo "1. Проверка доступности узлов кластера:"
echo "   Мастер-нода (192.168.56.10):"
ping -c 2 192.168.56.10 >/dev/null && echo "   ✓ Доступна" || echo "   ✗ Недоступна"
echo "   Воркер-нода (192.168.56.11):"
ping -c 2 192.168.56.11 >/dev/null && echo "   ✓ Доступна" || echo "   ✗ Недоступна"
echo ""

echo "2. Проверка балансировщика нагрузки (NGINX):"
curl -s http://192.168.56.10/status | head -5
echo ""

echo "3. Тестирование балансировки нагрузки:"
echo "   Отправка 5 запросов через балансировщик:"
for i in {1..5}; do
    echo "   Запрос $i: $(curl -s http://192.168.56.10 | grep -o 'Worker Node\|master-node' | head -1)"
done
echo ""

echo "4. Проверка работы приложения:"
echo "   Прямой доступ к мастер-ноде:"
curl -s -o /dev/null -w "HTTP код: %{http_code}\n" http://192.168.56.10:3000
echo "   Прямой доступ к воркер-ноде:"
curl -s -o /dev/null -w "HTTP код: %{http_code}\n" http://192.168.56.11:3000
echo ""

echo "5. Проверка базы данных:"
echo "   Статус PostgreSQL:"
systemctl is-active postgresql >/dev/null && echo "   ✓ Запущена" || echo "   ✗ Не запущена"
echo ""

echo "6. Проверка мониторинга:"
echo "   Node Exporter (метрики):"
curl -s http://192.168.56.10:9100/metrics | head -3
echo ""

echo "7. Сценарии отказоустойчивости:"
echo "   а) Остановка сервиса на воркер-ноде:"
echo "      systemctl stop cluster-app"
echo "      systemctl status cluster-app"
echo "   б) Проверка балансировки после остановки:"
echo "      curl http://192.168.56.10"
echo "   в) Запуск сервиса обратно:"
echo "      systemctl start cluster-app"
echo ""

echo "8. Проверка сетевой связности:"
echo "   С мастер-ноды на воркер:"
ssh appuser@192.168.56.11 "hostname" 2>/dev/null && echo "   ✓ SSH доступен" || echo "   ✗ SSH недоступен"
echo ""

echo "=== КОНЕЦ СЦЕНАРИЯ ==="
echo ""
echo "Доступные адреса:"
echo "  • Балансировщик: http://192.168.56.10"
echo "  • Статус NGINX: http://192.168.56.10/status"
echo "  • Мастер-нода: http://192.168.56.10:3000"
echo "  • Воркер-нода: http://192.168.56.11:3000"
echo "  • Метрики: http://192.168.56.10:9100"
echo ""
echo "Для проверки работы балансировщика выполните:"
echo "  for i in {1..10}; do curl -s http://192.168.56.10 | grep 'Server:'; done"