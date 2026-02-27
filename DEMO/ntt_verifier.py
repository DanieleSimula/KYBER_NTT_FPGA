#!/usr/bin/env python3
"""
NTT Verifier — FPGA vs C reference
------------------------------------
Loop:
  1. Chiede se generare un polinomio random o usare dati.txt
  2. Scrive il polinomio in dati.txt e lo copia nella clipboard
  3. Compila ntt.c (solo al primo avvio) e calcola il riferimento
  4. Trasmette il polinomio alla FPGA via UART
  5. Attende che l'utente premi start_butterfly e start_tx
  6. Riceve i 256 valori dalla FPGA via UART
  7. Confronta e riporta differenze
  8. Chiede se ricominciare
"""

import serial
import struct
import time
import subprocess
import sys
import os
import random
import shutil
from pathlib import Path

# =============================================================================
# CONFIGURAZIONE
# =============================================================================
SERIAL_PORT = 'COM4'
BAUD_RATE   = 9600
POLY_SIZE   = 256
KYBER_Q     = 3329

DELAY_BETWEEN_BYTES = 0.001   # pausa tra MSB e LSB di ogni coefficiente
DELAY_BETWEEN_WORDS = 0.002   # pausa tra coefficienti consecutivi

TIMEOUT_FIRST = 30.0   # attesa primo byte RX (dopo start_tx)
TIMEOUT_LINE  = 10.0   # attesa tra righe successive

SCRIPT_DIR = Path(__file__).parent
DATI_TXT   = SCRIPT_DIR / 'dati.txt'

ROOT_DIR   = Path(__file__).parents[5]   # HNTT/
NTT_C_FILE = ROOT_DIR / 'ntt.c'
NTT_EXE    = ROOT_DIR / 'ntt_ref.exe'

# =============================================================================
# POLINOMIO
# =============================================================================

def ask_mode() -> str:
    print()
    print('  Modalità:')
    print('    [1]  Genera polinomio RANDOM')
    print('    [2]  Usa polinomio da dati.txt')
    print()
    while True:
        choice = input('  Scelta [1/2]: ').strip()
        if choice in ('1', '2'):
            return choice
        print('  Inserisci 1 o 2.')


def generate_polynomial() -> list[int]:
    return [random.randint(0, KYBER_Q - 1) for _ in range(POLY_SIZE)]


def load_polynomial(path: Path) -> list[int]:
    content = path.read_text()
    tokens  = content.replace(',', ' ').replace('\n', ' ').split()
    numbers = [int(t) for t in tokens if t.strip()]
    if len(numbers) < POLY_SIZE:
        print(f'  [!] Trovati {len(numbers)} coeff, aggiungo zeri.')
        numbers.extend([0] * (POLY_SIZE - len(numbers)))
    elif len(numbers) > POLY_SIZE:
        numbers = numbers[:POLY_SIZE]
    return numbers


# =============================================================================
# RIFERIMENTO C
# =============================================================================

def find_gcc() -> str:
    gcc = shutil.which('gcc')
    if gcc:
        return gcc
    for p in [r'C:\mingw64\bin\gcc.exe', r'C:\mingw32\bin\gcc.exe',
              r'C:\msys64\mingw64\bin\gcc.exe']:
        if os.path.isfile(p):
            return p
    print('[✗] gcc non trovato. Assicurati che MinGW sia nel PATH.')
    sys.exit(1)


def compile_ntt() -> None:
    gcc = find_gcc()
    print(f'  [*] Compilo {NTT_C_FILE.name} con gcc...')
    result = subprocess.run(
        [gcc, '-O2', '-o', str(NTT_EXE), str(NTT_C_FILE)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print('ERRORE compilazione:\n' + result.stderr)
        sys.exit(1)
    print('  [✓] Compilazione OK')


def run_ntt_reference(polynomial: list[int]) -> list[int]:
    stdin_data = '\n'.join(str(v) for v in polynomial) + '\n'
    result = subprocess.run(
        [str(NTT_EXE)], input=stdin_data, capture_output=True, text=True
    )
    if result.returncode != 0:
        print('ERRORE ntt_ref.exe:\n' + result.stderr)
        sys.exit(1)
    values = []
    for line in result.stdout.splitlines():
        try:
            values.append(int(line.strip()))
        except ValueError:
            pass
    if len(values) != POLY_SIZE:
        print(f'ERRORE: ntt_ref ha restituito {len(values)} valori, attesi {POLY_SIZE}')
        print('  stdout raw:\n' + result.stdout[:300])
        sys.exit(1)
    return values

# =============================================================================
# TRASMISSIONE UART → FPGA
# =============================================================================

def clamp_int16(v: int) -> int:
    return max(-32768, min(32767, v))


def transmit_polynomial(poly: list[int]) -> None:
    print(f'\n  [*] Apertura {SERIAL_PORT} per trasmissione...')
    try:
        ser = serial.Serial(
            port=SERIAL_PORT, baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE, timeout=1
        )
    except serial.SerialException as e:
        print(f'  [✗] Errore apertura porta: {e}')
        sys.exit(1)

    print(f'  [*] Trasmissione {POLY_SIZE} coefficienti...')
    bytes_sent = 0
    try:
        for i, coeff in enumerate(poly):
            data = struct.pack('>h', clamp_int16(coeff))
            ser.write(data[0:1])
            time.sleep(DELAY_BETWEEN_BYTES)
            ser.write(data[1:2])
            bytes_sent += 2
            if (i + 1) % 32 == 0:
                pct = (i + 1) / POLY_SIZE * 100
                print(f'    [{pct:5.1f}%] {i+1:3d}/{POLY_SIZE} coefficienti trasmessi')
            time.sleep(DELAY_BETWEEN_WORDS)
        time.sleep(0.5)
    finally:
        ser.close()

    print(f'  [✓] Trasmissione completata ({bytes_sent} bytes)')

# =============================================================================
# RICEZIONE UART ← FPGA
# =============================================================================

def parse_fpga_line(line: str) -> int | None:
    """Formato data_converter: ±XXXXXR — rimuove suffisso R e converte."""
    line = line.strip().replace('\r', '')
    if not line:
        return None
    if line.upper().endswith('R'):
        line = line[:-1].strip()
    try:
        return int(line)
    except ValueError:
        return None


def receive_from_fpga() -> list[int]:
    print(f'\n  [*] Apertura {SERIAL_PORT} per ricezione'
          f' (attesa max {TIMEOUT_FIRST:.0f}s)...')
    try:
        ser = serial.Serial(
            port=SERIAL_PORT, baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE, timeout=TIMEOUT_FIRST
        )
    except serial.SerialException as e:
        print(f'  [✗] Errore apertura porta: {e}')
        sys.exit(1)

    values = []
    try:
        while len(values) < POLY_SIZE:
            raw = ser.readline()
            if not raw:
                if len(values) == 0:
                    print(f'\n  [✗] Nessun dato ricevuto entro {TIMEOUT_FIRST}s.')
                    print('       Hai premuto start_tx sulla FPGA?')
                else:
                    print(f'\n  [!] Timeout dopo {len(values)} valori.')
                break
            val = parse_fpga_line(raw.decode('ascii', errors='ignore'))
            if val is None:
                continue
            values.append(val)
            if len(values) == 1:
                ser.timeout = TIMEOUT_LINE   # timeout stretto dopo il primo valore
            if len(values) % 32 == 0:
                pct = len(values) / POLY_SIZE * 100
                print(f'    [{pct:5.1f}%] {len(values):3d}/{POLY_SIZE} valori ricevuti')
    finally:
        ser.close()

    print(f'  [✓] Ricezione completata ({len(values)} valori)')
    return values

# =============================================================================
# CONFRONTO
# =============================================================================

def compare(expected: list[int], actual: list[int]) -> bool:
    print()
    print('='*60)
    print('  VERIFICA')
    print('='*60)

    n_act = len(actual)
    if n_act != POLY_SIZE:
        print(f'  [!] Ricevuti {n_act} valori, attesi {POLY_SIZE}. Confronto parziale.')

    n_cmp = min(POLY_SIZE, n_act)
    diffs = {i for i in range(n_cmp) if expected[i] != actual[i]}
    for i in range(n_act, POLY_SIZE):
        diffs.add(i)

    # Tabella completa
    print()
    print(f"  {'idx':>4}  {'atteso (C)':>12}  {'FPGA':>12}  {'':>2}")
    print(f"  {'-'*4}  {'-'*12}  {'-'*12}  {'-'*2}")
    for i in range(n_cmp):
        exp_val = expected[i]
        act_val = actual[i]
        marker  = ' ✗' if i in diffs else '  '
        print(f'  {i:>4}  {exp_val:>12}  {act_val:>12}  {marker}')
    for i in range(n_act, POLY_SIZE):
        print(f'  {i:>4}  {expected[i]:>12}  {"MANCANTE":>12}{"":>14}  ✗')

    # Riepilogo
    print()
    if not diffs:
        print(f'  [✓] CORRETTO — tutti i {n_cmp} valori coincidono con il riferimento C')
    else:
        print(f'  [✗] {len(diffs)} differenze su {n_cmp} confrontati')

    return len(diffs) == 0

# =============================================================================
# MAIN
# =============================================================================

def run_test() -> bool:
    """Esegue un singolo ciclo di test. Ritorna True se corretto."""

    # 1. Polinomio
    mode = ask_mode()
    print()

    if mode == '1':
        print(f'  [1/4] Genero polinomio random ({POLY_SIZE} coeff in [0, {KYBER_Q-1}])...')
        poly = generate_polynomial()
    else:
        if not DATI_TXT.exists():
            print(f'  [!] {DATI_TXT} non trovato.')
            sys.exit(1)
        print('  [1/4] Carico polinomio da dati.txt...')
        poly = load_polynomial(DATI_TXT)

    print(f'         range: [{min(poly)}, {max(poly)}]')

    # 2. Riferimento C
    print()
    print('  [2/4] Calcolo NTT di riferimento...')
    expected = run_ntt_reference(poly)
    print(f'         range output: [{min(expected)}, {max(expected)}]')

    # 3. Trasmissione
    print()
    print('  [3/4] Trasmissione polinomio alla FPGA...')
    input('         Premi INVIO per iniziare la trasmissione...')
    transmit_polynomial(poly)

    # 4. Ricezione
    print()
    print('  [4/4] Ricezione risultati dalla FPGA.')
    print('        → Premi start_butterfly sulla FPGA e attendi fine NTT')
    print('        → Poi premi start_tx')
    input('        Premi INVIO quando sei pronto...')
    actual = receive_from_fpga()

    # 5. Confronto
    return compare(expected, actual)


def main():
    print()
    print('='*60)
    print('  NTT VERIFIER  —  FPGA vs C reference')
    print('='*60)

    if not NTT_C_FILE.exists():
        print(f'  [!] {NTT_C_FILE} non trovato.')
        sys.exit(1)

    # Compilazione una volta sola all'avvio
    print()
    compile_ntt()

    all_ok = True
    while True:
        print()
        print('-'*60)
        ok = run_test()
        if not ok:
            all_ok = False

        print()
        again = input('  Vuoi testare un altro polinomio? [s/n]: ').strip().lower()
        if again not in ('s', 'si', 'sì', 'y', 'yes'):
            break

    print()
    print('='*60)
    print('  SESSIONE TERMINATA')
    print('='*60)
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main())
