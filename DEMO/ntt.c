#include <stdio.h>
#include <stdint.h>


/* =========================
   COSTANTI DI KYBER
   ========================= */


/* Modulo usato da Kyber */
#define KYBER_Q 3329


/* QINV = -q^{-1} mod 2^16
   è una costante usata nella Montgomery reduction.
   Valore preso dalle implementazioni reference di Kyber. */
#define QINV -3327  


/* =========================
   VETTORE DELLE RADICI (ZETAS)
   128 valori usati dalla NTT
   ========================= */


const int16_t zetas[128] = {
  -1044,  -758,  -359, -1517,  1493,  1422,   287,   202,
   -171,   622,  1577,   182,   962, -1202, -1474,  1468,
    573, -1325,   264,   383,  -829,  1458, -1602,  -130,
   -681,  1017,   732,   608, -1542,   411,  -205, -1571,
   1223,   652,  -552,  1015, -1293,  1491,  -282, -1544,
    516,    -8,  -320,  -666, -1618, -1162,   126,  1469,
   -853,   -90,  -271,   830,   107, -1421,  -247,  -951,
   -398,   961, -1508,  -725,   448, -1065,   677, -1275,
  -1103,   430,   555,   843, -1251,   871,  1550,   105,
    422,   587,   177,  -235,  -291,  -460,  1574,  1653,
   -246,   778,  1159,  -147,  -777,  1483,  -602,  1119,
  -1590,   644,  -872,   349,   418,   329,  -156,   -75,
    817,  1097,   603,   610,  1322, -1285, -1465,   384,
  -1215,  -136,  1218, -1335,  -874,   220, -1187, -1659,
  -1185, -1530, -1278,   794, -1510,  -854,  -870,   478,
   -108,  -308,   996,   991,   958, -1460,  1522,  1628
};


/* =========================
   montgomery_reduce
   riduce un intero a 32 bit in un valore rappresentativo mod KYBER_Q
   usando il metodo di Montgomery ottimizzato per 2^16
   ========================= */


/*
   Argomento:
     a : int32_t - prodotto (o valore intermedio) da ridurre


   Output:
     valore int16_t congruente a a * R^{-1} mod KYBER_Q,
     dove R = 2^16 (implementazione tipica delle riduzioni Montgomery)
*/
int16_t montgomery_reduce(int32_t a)
{
    int16_t t;


    /* t = (a * QINV) mod 2^16, ma scritto come cast a int16_t.
       QINV è scelto tale che (a - t * KYBER_Q) sia divisibile per 2^16. */
    t = (int16_t)a * QINV;


    /* Calcolo: (a - t * KYBER_Q) >> 16
       Dopo la sottrazione il risultato è un multiplo di 2^16;
       >>16 implementa la divisione per 2^16, il risultato è il valore ridotto
       (questo sfrutta aritmetica con segno in C, ma per gli interi tipici
       e i range usati in Kyber è corretto). */
    t = (a - (int32_t)t * KYBER_Q) >> 16;


    return t;
}


/* =========================
   fqmul
   moltiplicazione "modular-friendly" che usa montgomery_reduce
   ========================= */


/*
  Argomenti:
    a, b : int16_t - operandi (rappresentati nella base Montgomery)
  Ritorna:
    montgomery_reduce(a * b)
  Nota:
    a e b devono essere nell'intervallo corretto (tipicamente rappresentati
    per essere compatibili con Montgomery). La funzione ritorna il prodotto
    ridotto in forma coerente con l'implementazione di Kyber.
*/
static int16_t fqmul(int16_t a, int16_t b)
{
    /* Esegui il prodotto a 32-bit per evitare overflow 16x16 */
    return montgomery_reduce((int32_t)a * b);
}








/* =========================
   ntt
   Trasformata in-place su array di 256 coefficienti (Kyber standard)
   ========================= */


/*
  Argomenti:
    r[256] : polinomio (coefficenti) caricati in memoria
  Funzionamento interno:
    - struttura a livelli come nella FFT iterativa (Cooley-Tukey style)
    - per ogni livello si esegue una serie di "butterfly" su coppie di elementi
    - zetas[] fornisce la radice (moltiplicatore) per ogni butterfly
    - fqmul fa la moltiplicazione modulare (Montgomery)


*/






void ntt(int16_t r[256]) {  
  // r: vettore di 256 coefficienti su cui viene applicata la NTT in-place


  unsigned int len, start, j, k;
  int16_t t, zeta;  
  // len  = grandezza del blocco butterfly (viene dimezzata a ogni stadio)
  // start = indice di inizio di ciascun blocco da 2*len
  // j = indice interno della butterfly
  // k = indice per iterare nell’array zetas[]
  // t = temporaneo per il risultato della moltiplicazione
  // zeta = twiddle factor preso da zetas[]


  k = 1;  
  // L’array zetas viene usato a partire dall’indice 1.


  for(len = 128; len >= 2; len >>= 1) {
    // Ciclo sugli stadi della NTT:
    // len parte da 128 → 64 → 32 → ... → 2.
    // Ad ogni iterazione si lavora su blocchi sempre più piccoli.


    for(start = 0; start < 256; start = j + len) {
      // Suddivide il vettore in blocchi di grandezza 2*len.
      // start avanza automaticamente a fine loop tramite start = j + len.
      // (Quando j arriva a start+len, j+len = start+2*len → nuovo blocco)


      zeta = zetas[k++];  
      // Twiddle factor per questo blocco.
      // Ogni blocco utilizza un diverso zeta.


      for(j = start; j < start + len; j++) {
        // Ciclo interno della butterfly.
        // Ogni iterazione lavora sulla coppia di elementi:
        //   r[j]       (parte bassa)
        //   r[j+len]   (parte alta)


        t = fqmul(zeta, r[j + len]);
        // Moltiplica il coefficiente alto per il twiddle factor.


        r[j + len] = r[j] - t;
        // Aggiorna la parte alta della butterfly.


        r[j] = r[j] + t;
        // Aggiorna la parte bassa della butterfly.
      }
    }
  }
}






/* =========================
   MAIN
   Legge 256 interi da stdin, applica NTT, stampa i risultati uno per riga.
   ========================= */


int main()
{
    int16_t poly[256];
    int val, i;

    for (i = 0; i < 256; i++) {
        if (scanf("%d", &val) != 1) {
            fprintf(stderr, "ERRORE: attesi 256 interi, letti solo %d\n", i);
            return 1;
        }
        poly[i] = (int16_t)val;
    }

    ntt(poly);

    for (i = 0; i < 256; i++) {
        printf("%d\n", (int)poly[i]);
    }

    return 0;
}
