# KYBER_NTT_FPGA

Acceleratore hardware della **Number Theoretic Transform (NTT)** Kyber,
implementato su FPGA Basys3 (Xilinx Artix-7) con interfaccia UART.

Riceve 256 coefficienti a 16 bit via UART, esegue la NTT (q = 3329) con architettura
a doppia butterfly e ritrasmette i risultati in formato ASCII.

**Board:** Digilent Basys3 — `xc7a35tcpg236-1` | **UART:** 9600 baud rate

Daniele Simula, Ivan Ezza, Daniele Zallu, Federico Corvaglia, Luca Ligios
---

## Inizializzazione del progetto Vivado

### Opzione A — Apertura diretta

```
Vivado → Open Project → KYBER_NTT_FPGA/KYBER_NTT_FPGA.xpr
```

### Opzione B — Da script TCL

Aprire la **Vivado Tcl Console**, posizionarsi nella cartella del progetto ed eseguire:

```tcl
cd {C:/percorso/del/progetto}
source KYBER_NTT_FPGA.tcl -tclargs --origin_dir ./a/b/c
```


## Programmazione della board
È disponibile un bitstream precompilato in `BITSTREAM/ntt_top.bit`.

1. Collegare la Basys3 via USB
2. In Vivado: **Open Hardware Manager → Open Target → Auto Connect**
3. **Program Device** → selezionare `BITSTREAM/ntt_top.bit`

oppure se lo si preferisce
Eseguire **Run Synthesis → Run Implementation → Generate Bitstream** per rigenerare il bitstream.


## Demo e utilizzo

Prima di avviare gli script, impostare la porta seriale corretta, controllare su **gestione dispositivi → porte com** la porta seriale disponibile e modificare la linea seguente negli script python che si intende utilizzare:

```python
SERIAL_PORT = 'COM4'   
```

Prerequisiti Python:
```bash
pip install pyserial
```

---

### Demo 1 — Verifica automatica (`ntt_verifier.py`)

Confronta automaticamente l'output della FPGA con un riferimento calcolato in C.
Richiede `gcc` nel PATH (MinGW su Windows).

```bash
python DEMO/ntt_verifier.py
```

**Procedura:**

1. Scegliere se usare un polinomio **random** oppure caricare `dati.txt`
2. Lo script calcola il riferimento C e trasmette i coefficienti alla FPGA
3. Premere **`start_butterfly[BTNC/U18]`** sulla Basys3 e attendere il completamento della NTT
4. Premere **`start_tx[BTNU/T18]`** per avviare la trasmissione dei risultati
5. Lo script riceve i 256 valori, li confronta con il riferimento e stampa la tabella 


---

### Demo 2 — Trasmissione manuale (`Invio_poly.py`)

Invia un polinomio a scelta attingendo da `dati.txt` alla FPGA senza verifica automatica.
-

```bash
python DEMO/Invio_poly.py
```

Il file di input si imposta modificando la variabile `DATA_FILE` nello script.
Formato atteso: 256 interi separati da spazi, virgole o newline, range `[-32768, 32767]`.

Dopo la trasmissione:
1. Premere **`start_butterfly`** sulla Basys3
2. Premere **`start_tx`**
3. Leggere i risultati da qualsiasi terminale seriale **`putty consigliato`**(9600 baud_rate)

### Utilizzo generico

La FPGA è accessibile da **qualsiasi strumento** in grado di comunicare via seriale
a 9600 baud, 8N1 — non è necessario usare gli script Python inclusi.

1. Connettere alla porta COM della Basys3 (9600 baud rate)
2. Inviare 256 coefficienti a 16 bit in formato **big-endian signed** (MSB prima, poi LSB) — ogni coefficiente occupa 2 byte, totale 512 byte
3. Premere **BTNC** (`start_butterfly`) e attendere che **LED0** (`done`) si accenda
4. Premere **BTNU** (`start_tx`) per avviare la trasmissione
5. Leggere i 256 risultati dal terminale — ogni valore è una riga ASCII nel formato `±XXXXX`

Compatibilità: per tutta la durata dello sviluppo è stato utilizzato PuTTy come terminale seriale ma dovrebbe essere compatibile qualsiasi strumento in grado di ricevere la trasmissione della fpga via porta seriale.

---

## Controlli della board

### Switch

| Switch | Segnale | Funzione |
|--------|---------|----------|
| SW0 | `rst` | Reset generale |

### Pulsanti

| Pulsante | Posizione | Segnale | Funzione |
|----------|-----------|---------|----------|
| BTNC | Centro | `start_butterfly` | Avvia il calcolo NTT sui dati ricevuti |
| BTNU | Su | `start_tx` | Avvia la trasmissione dei risultati via UART |

### LED

| LED | Segnale | Significato |
|-----|---------|-------------|
| LED0 | `done` | NTT completata — risultati pronti in RAM |
| LED1 | `fifo_tx_full` | FIFO TX piena |
| LED2 | `fifo_tx_empty` | FIFO TX vuota |
| LED4 | `uart_mode` | Ram impostata in modalità uart è possibile ricevere e trasmettere via uart |
| LED14 | `fifo_rx_full` | FIFO RX piena |
| LED15 | `fifo_rx_empty` | FIFO RX vuota |
