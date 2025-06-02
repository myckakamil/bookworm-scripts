#!/bin/bash

# Konfiguracja
DURATION=300          # Czas trwania testu (w sekundach)
INTERVAL=5            # Interwał pomiaru (w sekundach)
LOG_FILE="temp_log.csv" # Plik wynikowy
STRESS_CORES=$(nproc) # Liczba rdzeni do obciążenia

# Nagłówek pliku CSV
echo "timestamp,cpu_temp,core_freq,gpu_temp" > "$LOG_FILE"

# Funkcja pomiaru temperatur
measure_temp() {
    # Temperatura CPU
    CPU_TEMP=$(sensors | grep 'CPU:' | awk '{print $2}' | sed 's/+//;s/°C//')
    
    # Taktowanie rdzenia
    CORE_FREQ=$(cat /proc/cpuinfo | grep 'MHz' | head -n 1 | awk '{print $4}')
    
    # Temperatura GPU (AMD)
    GPU_TEMP=$(sensors | grep 'edge:' | awk '{print $2}' | sed 's/+//;s/°C//')
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$CPU_TEMP,$CORE_FREQ,$GPU_TEMP"
}

# Uruchomienie obciążenia
echo "Rozpoczęcie testu obciążenia ($DURATION sekund)..."
stress-ng --cpu $STRESS_CORES --timeout $DURATION &

# Pomiar temperatur w pętli
echo "Monitorowanie temperatur..."
while sleep $INTERVAL; do
    # Sprawdź czy stress-ng jeszcze działa
    if ! pgrep stress-ng >/dev/null; then
        break
    fi
    measure_temp >> "$LOG_FILE"
done

echo "Test zakończony. Wyniki zapisano w $LOG_FILE"
