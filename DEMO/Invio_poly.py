#!/usr/bin/env python3
"""
UART Polynomial Transmitter for FPGA NTT
-----------------------------------------
Legge un polinomio da file di testo (256 coefficienti interi),
converte ogni coefficiente in 16-bit signed integer (big-endian),
e trasmette alla FPGA via UART.

Formato file: 256 numeri separati da spazi, virgole o newline.
Range valori: -32768 a +32767 (16-bit signed)
"""

import serial
import struct
import time
from pathlib import Path


# =============================================================================
# CONFIGURAZIONE
# =============================================================================
SERIAL_PORT = 'COM4'      # Porta seriale (es: 'COM3' Windows, '/dev/ttyUSB0' Linux)
BAUD_RATE = 9600          # Velocità comunicazione
POLY_SIZE = 256           # Numero di coefficienti del polinomio
DATA_FILE = 'DoubleButterfly-Uart\PROGETTO.srcs\sources_1\imports\design_source\dati.txt'    # File contenente il polinomio

# Timing (in secondi)
DELAY_BETWEEN_BYTES = 0.001   # Pausa tra MSB e LSB
DELAY_BETWEEN_WORDS = 0.002   # Pausa tra numeri consecutivi


# =============================================================================
# FUNZIONI
# =============================================================================

def load_polynomial(file_path):
    """
    Carica il polinomio dal file.
    
    Args:
        file_path: percorso del file contenente i coefficienti
        
    Returns:
        Lista di 256 interi
        
    Raises:
        FileNotFoundError: se il file non esiste
        ValueError: se i dati non sono validi
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Il file '{file_path}' non esiste")
    
    # Leggi e processa il contenuto
    content = path.read_text()
    numbers_str = content.replace(',', ' ').replace('\n', ' ').split()
    numbers = [int(num.strip()) for num in numbers_str if num.strip()]
    
    # Normalizza a esattamente 256 valori
    if len(numbers) < POLY_SIZE:
        print(f"⚠ Trovati solo {len(numbers)} coefficienti, aggiungo {POLY_SIZE - len(numbers)} zeri")
        numbers.extend([0] * (POLY_SIZE - len(numbers)))
    elif len(numbers) > POLY_SIZE:
        print(f"⚠ Trovati {len(numbers)} coefficienti, uso solo i primi {POLY_SIZE}")
        numbers = numbers[:POLY_SIZE]
    
    return numbers


def clamp_int16(value):
    """Limita il valore al range int16: [-32768, 32767]"""
    return max(-32768, min(32767, value))


def int16_to_bytes(value):
    """
    Converte un intero in 2 bytes (16-bit signed, big-endian).
    
    Args:
        value: intero da convertire
        
    Returns:
        bytes: 2 bytes (MSB, LSB)
    """
    clamped = clamp_int16(value)
    return struct.pack('>h', clamped)


def transmit_polynomial(ser, polynomial):
    """
    Trasmette il polinomio alla FPGA via UART.
    
    Args:
        ser: oggetto serial.Serial
        polynomial: lista di 256 interi
        
    Returns:
        int: numero di bytes trasmessi
    """
    bytes_sent = 0
    print("\n" + "="*60)
    print("TRASMISSIONE IN CORSO")
    print("="*60)
    
    for i, coeff in enumerate(polynomial):
        # Converti in bytes
        data = int16_to_bytes(coeff)
        
        # Invia MSB
        ser.write(data[0:1])
        time.sleep(DELAY_BETWEEN_BYTES)
        
        # Invia LSB
        ser.write(data[1:2])
        bytes_sent += 2
        
        # Progress update ogni 32 coefficienti
        if (i + 1) % 32 == 0:
            progress = (i + 1) / POLY_SIZE * 100
            print(f"[{progress:5.1f}%] {i + 1:3d}/{POLY_SIZE} coefficienti ({bytes_sent:3d} bytes)")
        
        # Pausa tra coefficienti
        time.sleep(DELAY_BETWEEN_WORDS)
    
    return bytes_sent


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Funzione principale."""
    
    print("\n" + "="*60)
    print("UART POLYNOMIAL TRANSMITTER")
    print("="*60)
    
    ser = None
    
    try:
        # 1. Carica polinomio
        print(f"\n[1/3] Caricamento polinomio da '{DATA_FILE}'...")
        polynomial = load_polynomial(DATA_FILE)
        
        print(f"✓ Caricati {len(polynomial)} coefficienti")
        print(f"  Range: [{min(polynomial)}, {max(polynomial)}]")
        
        # 2. Apri porta seriale
        print(f"\n[2/3] Apertura porta seriale {SERIAL_PORT} @ {BAUD_RATE} baud...")
        ser = serial.Serial(
            port=SERIAL_PORT,
            baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
        print("✓ Porta seriale aperta")
        
        # 3. Trasmetti
        print(f"\n[3/3] Trasmissione polinomio...")
        bytes_sent = transmit_polynomial(ser, polynomial)
        
        # Attendi processamento FPGA
        time.sleep(0.5)
        
        # Risultato
        print("\n" + "="*60)
        print("✓ TRASMISSIONE COMPLETATA CON SUCCESSO")
        print("="*60)
        print(f"  Coefficienti: {len(polynomial)}")
        print(f"  Bytes inviati: {bytes_sent}")
        
    except FileNotFoundError as e:
        print(f"\n✗ ERRORE: {e}")
        print(f"  Crea un file '{DATA_FILE}' con {POLY_SIZE} numeri interi")
        
    except ValueError as e:
        print(f"\n✗ ERRORE: Dati non validi nel file")
        print(f"  Il file deve contenere solo numeri interi")
        print(f"  Dettagli: {e}")
        
    except serial.SerialException as e:
        print(f"\n✗ ERRORE SERIALE: {e}")
        print(f"  Verifica che la porta {SERIAL_PORT} sia corretta e disponibile")
        
    except KeyboardInterrupt:
        print("\n\n⚠ Trasmissione interrotta dall'utente")
        
    except Exception as e:
        print(f"\n✗ ERRORE IMPREVISTO: {e}")
        
    finally:
        if ser and ser.is_open:
            ser.close()
            print("\nPorta seriale chiusa.")


if __name__ == '__main__':
    main()
